require 'xmlrpc/client'

# Hack XMLRPC::ParseContentType#parse_content_type {{{
module XMLRPC
  module ParseContentType
    def parse_content_type(str)
      # Hack: tasko API does not return "Content-Type"
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

      # Hack: ignore empty line in HTTP header
      str = sock.readline if str.empty?

      m = /\AHTTP(?:\/(\d+\.\d+))?\s+(\d\d\d)\s*(.*)\z/in.match(str) or
        raise HTTPBadResponse, "wrong status line: #{str.dump}"
      m.captures
    end
  end
end

# class TaskoAPI {{{
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
# }}}

