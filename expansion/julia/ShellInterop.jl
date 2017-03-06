module ShellInterop
export shell, configure_shell,
       eval_sh, read_sh, end_sh,
       incomplete_msg_sh, err_sh, eval_file_sh,
       FXCRD_PATH

const FXCRD_PATH = chomp(readstring(`fxcrd_path`))

struct Shell{EvalIO<:IO,ReadIO<:IO}
  eval::EvalIO
  read::ReadIO
end

mutable struct ShellConfig
  eval::String
  read::String
end
const SHELL_CONFIG = ShellConfig("","")

function configure_shell(ev,rd)
  SHELL_CONFIG.eval = ev
  SHELL_CONFIG.read = rd
end

function shell(f)
  open("$(SHELL_CONFIG.eval)", "w") do eval_io
    open("$(SHELL_CONFIG.read)", "r") do read_io
      f(Shell(eval_io, read_io))
    end
  end
end

function sh_fxcrd_signal(name)
  "\$\${\$fxcrd_$name\$}\$\$"
end

function sh_send_fxcrd_signal(sh, name)
  println(sh.eval, sh_fxcrd_signal(name))
  flush(sh.eval)
end

function err_sh(sh)
  sh_send_fxcrd_signal(sh, "error")
end

function end_sh(sh)
  sh_send_fxcrd_signal(sh, "end")
end

function read_sh(sh, cmd)
  println(sh.eval, cmd)
  sh_send_fxcrd_signal(sh, "read")

  line=""
  result=""
  while line != sh_fxcrd_signal("return")
    result="$result\n$line"
    line=readline(sh.read)
  end
  return lstrip(result, '\n')
end

function clear_sh(sh)
  println(sh.eval, "")
end

function incomplete_msg_sh(sh, msg)
  println(sh.eval, msg)
end

function eval_sh(sh, cmd)
  println(sh.eval, cmd)
  sh_send_fxcrd_signal(sh, "eval")
end

function eval_file_sh(sh, file)
  println(sh.eval, ". '$file'")
  sh_send_fxcrd_signal(sh, "eval")
end

end
