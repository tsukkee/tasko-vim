ruby <<EOF

require 'xmlrpc/client'

# Hack XMLRPC::ParseContentType#parse_content_type {{{
module XMLRPC
  module ParseContentType
    def parse_content_type(str)
      # Hack:
      # tasko API does not return "Content-Type"
      # assume "Content-Type: text/xml;utf-8"
      ["text/xml", "utf-8"]
    end
  end
end
# }}}

# Hack Net::HTTP::HTTPResponse.read_status_line {{{
module Net
  class << HTTPResponse
    def read_status_line(sock)
      str = sock.readline

      # Hack:
      # Tasko API sometimes blank line
      # ignore blank line in HTTP header
      str = sock.readline if str.empty?

      m = /\AHTTP(?:\/(\d+\.\d+))?\s+(\d\d\d)\s*(.*)\z/in.match(str) or
        raise HTTPBadResponse, "wrong status line: #{str.dump}"
      m.captures
    end
  end
end
# }}}

# module VIM extension {{{
module VIM
  # for VIM.function
  @@__PROCS__ = {}

  class << self
    def echoerr(message)
      VIM.command("echoerr \"#{message}\"")
    end

    def exists?(name)
      VIM.evaluate("exists(\"#{name}\")") == '1'
    end

    def confirm?(message)
      VIM.evaluate("confirm(\"#{message}\")") == '1'
    end

    def function(name, &func)
      vim_args  = []
      ruby_args = []
      func.arity.times {|i|
        vim_args  << "a#{i}" 
        ruby_args << "VIM.evaluate(\"a:a#{i}\")"
      }
  
      @@__PROCS__[name] = func
  
      command = <<-EOF
        function! #{name}(#{vim_args.join(",")})
        ruby VIM.get_proc("#{name}").call(#{ruby_args.join(",")})
        endfunction
      EOF
  
      VIM.command(command)
    end

    def get_proc(name)
      @@__PROCS__[name]
    end
  end

  class Buffer
    def all_lines
      ret = []
      1.upto(length) {|i|
        yield self[i] if block_given?

        ret << self[i]
      }
      ret
    end
  end
end
# }}}

# class TaskoAPI {{{
class TaskoAPI
  # Tasko API returns "nil" for invalid actions
  XMLRPC::Config.module_eval { remove_const(:ENABLE_NIL_PARSER) }
  XMLRPC::Config.const_set(:ENABLE_NIL_PARSER, true)

  # endpoint
  @@URL = "http://taskodone.com/api"

  def initialize(id, pass)
    @id = id
    @pass = pass
    @client = XMLRPC::Client.new2(@@URL)
  end

  def papers
    @client.call("papers", @id, @pass)
  end

  def paper(name)
    @client.call("paper", @id, @pass, name)
  end

  def rename(old, new)
    @client.call("rename", @id, @pass, old, new)
  end

  def edit(name, data)
    @client.call("edit", @id, @pass, name, data)
  end

  def newpaper(name, data = "")
    @client.call("new", @id, @pass, name, data)
  end

  def delete(name)
    @client.call("delete", @id, @pass, name)
  end
end
# }}}

# class Tasko {{{
class Tasko
  def initialize(id, token)
    @api = TaskoAPI.new(id, token)
  end

  def list
    @api.papers.each{|p| VIM.message(p)}
  end

  def read(name)
    body = @api.paper(name)
    
    if body.nil?
      VIM.echoerr("\"#{name}\" does not exist on Tasko server")
      return
    end

    VIM.command("e #{name}.taskpaper")
    VIM.command("setlocal buftype=nofile")
    VIM.command("setlocal fenc=utf-8")

    body.each_with_index {|l, i|
      VIM::Buffer.current.append(i, l.chomp)
    }
  end

  def write
    if VIM.evaluate("&filetype") != "taskpaper"
      VIM.echoerr("This file is not Taskpaper file.")
      return
    end

    return unless VIM.confirm?("really?")

    if VIM.evaluate("&fenc") != "utf-8"
      VIM.echoerr("fileencoding(fenc) must be utf-8")
    end

    name = VIM::Buffer.current.name
    basename = File.basename(name, '.taskpaper')

    data = VIM::Buffer.current.all_lines.join("\n")
    result = @api.edit(basename, data)

    if result.nil?
      VIM.message("\"#{basename}\" does not exist on Tasko server")

      if VIM.confirm?("create?")
        result =  @api.newpaper(basename, data)
      end
    end
  end
end
# }}}

# initialize {{{
if VIM.exists?("g:tasko_id") && VIM.exists?("g:tasko_token")
  tasko_id    = VIM.evaluate('g:tasko_id')
  tasko_token = VIM.evaluate('g:tasko_token')

  tasko = Tasko.new(tasko_id, tasko_token)

  VIM.function("s:TaskoList") {
    VIM.message("Tasko List")
    tasko.list
  }

  VIM.function("s:TaskoRead") {|name|
    VIM.message("Tasko Read")
    tasko.read(name)
  }

  VIM.function("s:TaskoWrite") {
    VIM.message("Tasko Write")
    tasko.write
  }
else
  VIM.message("Please set g:tasko_id and g:tasko_token")

  # define empty functions
  ["s:TaskoList", "s:TaskoRead", "s:TaskoWrite"].each {|func|
    VIM.function(func) {
      VIM.message("Please set g:tasko_id and g:tasko_token")
    }
  }
end
# }}}

EOF

" Define vim commands {{{
command! TaskoList call s:TaskoList()
command! -nargs=1 TaskoRead call s:TaskoRead(<f-args>)
command! TaskoWrite call s:TaskoWrite()
" }}}
