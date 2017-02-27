#!/usr/bin/env julia

__precompile__(true)
module Fxcrd

include("./ShellInterop.jl")
include("./Tokenize.jl")
include("./ShellCompiler.jl")
include("./MacroDatabase.jl")
include("./MacroExpander.jl")
include("./StartMacros.jl")
include("./Source.jl")
include("./Interactive.jl")

using .Tokenize
using .MacroExpander
using .ShellInterop
using .Source

function main(ev,rd,files...)
  try
    configure_shell(ev,rd)
    source(files...)
  catch err
    shell(err_sh)
    shell(end_sh)
    rethrow(err)
    exit()
  finally
    shell(end_sh)
  end
end

greenprint(x) = print_with_color(:green, x, "\n")

function interactive()
  println()
  greenprint("  ------------------")
  greenprint("   --- hello !! --- ")
  greenprint("  ------------------")
  println()

  open(`fxcrd_compile --print --send`) do compiler
    ev = readline(compiler, chomp=true)
    rd = readline(compiler, chomp=true)
    configure_shell(ev, rd)

    shell() do sh
      eval_sh(sh, """
        hi()    { echo "\033[32;1m :)\033[0m"; }
        hello() { echo "\033[32;1m :)\033[0m"; }
      """)
      Interactive.main_loop(sh)
      greenprint(" bye bye! ")
      println()
      end_sh(sh)
    end
  end
end

end
