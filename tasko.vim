command! TaskoList call <SID>TaskoList()
command! -nargs=1 TaskoRead call <SID>TaskoRead(<f-args>)
command! TaskoWrite call <SID>TaskoWrite()

function! s:TaskoList()
    ruby tasko_list
endfunction

function! s:TaskoRead(name)
    ruby tasko_read(VIM.evaluate('a:name'))
endfunction

function! s:TaskoWrite()
    ruby tasko_write
endfunction

ruby <<EOF
require 'tasko.rb'

def tasko_list
    $tasko.papers.each{|p| puts p}
end

def tasko_read(name)
    body = $tasko.paper(name)
    
    if body.nil?
        puts '"' + name + '" does not exist on Tasko server'
    else 
        VIM.command("e " + name + ".taskpaper")
        body.each_with_index {|l, i|
            VIM::Buffer.current.append(i, l.chomp)
        }
    end
end

def tasko_write
    if VIM.evaluate("&filetype") != "taskpaper"
        puts "This file is not Taskpaper file."
        return
    end

    return if VIM.evaluate('confirm("really?")') == '0'

    name = VIM::Buffer.current.name
    basename = File.basename(name, '.taskpaper')

    data = get_buffer
    result = $tasko.edit(basename, data)

    if result.nil?
        puts '"' + basename + '" does not exist on Tasko server'

        if VIM.evaluate('confirm("create?")') == '1'
            result =  $tasko.newpaper(basename, data)
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

$tasko = TaskoAPI.new(tasko_id, tasko_token)

EOF
