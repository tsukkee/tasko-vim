" Define vim commands
command! TaskoList call <SID>TaskoList()
command! -nargs=1 TaskoRead call <SID>TaskoRead(<f-args>)
command! TaskoWrite call <SID>TaskoWrite()

" Define vim functions
function! s:TaskoList()
    ruby $tasko.list
endfunction

function! s:TaskoRead(name)
    ruby $tasko.read(VIM.evaluate('a:name'))
endfunction

function! s:TaskoWrite()
    ruby $tasko.write
endfunction

ruby <<EOF
require 'xmlrpc/client'

# Hack XMLRPC::ParseContentType#parse_content_type {{{
# Tasko API does not return "Content-Type"
module XMLRPC
  module ParseContentType
    def parse_content_type(str)
      ["text/xml", "utf-8"]
    end
  end
end
# }}}

class TaskoAPI
  # Tasko API returns "nil" for invalid actions
  XMLRPC::Config.module_eval { remove_const(:ENABLE_NIL_PARSER) }
  XMLRPC::Config.const_set(:ENABLE_NIL_PARSER, true)

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

class Tasko
  def initialize(id, token)
    @api = TaskoAPI.new(id, token)
  end

  def list
    @api.papers.each{|p| puts p}
  end

  def read(name)
    body = @api.paper(name)
    
    if body.nil?
      puts '"' + name + '" does not exist on Tasko server'
      return
    end

    VIM.command("e " + name + ".taskpaper")
    VIM.command("set buftype=nofile")
    body.each_with_index {|l, i|
      VIM::Buffer.current.append(i, l.chomp)
    }
  end

  def write
    if VIM.evaluate("&filetype") != "taskpaper"
      puts "This file is not Taskpaper file."
      return
    end

    return if VIM.evaluate('confirm("really?")') == '0'

    name = VIM::Buffer.current.name
    basename = File.basename(name, '.taskpaper')

    data = get_buffer
    result = @api.edit(basename, data)

    if result.nil?
      puts '"' + basename + '" does not exist on Tasko server'

      if VIM.evaluate('confirm("create?")') == '1'
        result =  @api.newpaper(basename, data)
      end
    end
  end
end

def get_buffer
  ret = []
  1.upto(VIM::Buffer.current.length) {|i|
    ret << VIM::Buffer.current[i]
  }
  ret.join("\n")
end

tasko_id    = VIM.evaluate('g:tasko_id')
tasko_token = VIM.evaluate('g:tasko_token')

$tasko = Tasko.new(tasko_id, tasko_token)

EOF
