command! TaskoList call <SID>TaskoList()
command! -nargs=1 TaskoRead call <SID>TaskoRead(<f-args>)

function! s:TaskoList()
    ruby VIM.command('echo "' + $tasko.papers.join("\n") + '"')
endfunction

function! s:TaskoRead(name)
    ruby <<EOF
       name = VIM.evaluate("a:name")
       body = $tasko.paper(name)
        
       if body.nil?
         puts '"' + name + '"' + "does not exist on Tasko server" 
       else 
         VIM.command("e " + name + ".taskpaper")
         body.each_with_index {|l, i|
           VIM::Buffer.current.append(i, l.chomp)
         }
       end
EOF
endfunction

ruby <<EOF
require 'config.rb'
require 'tasko.rb'

$tasko = TaskoAPI.new(ID, TOKEN)
EOF
