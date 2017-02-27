module MacroDatabase
using ..Fxcrd.ShellCompiler
using ..Fxcrd.ShellInterop
export Macro, Macros, get_macro, macrocall

struct Macro
  name::String
  func::Function
  eval::Bool
  meta::Bool
end
const Macros = Dict{String,Macro}()

function get_macro(name)
  @assert haskey(Macros, name) "macro $name not defined"
  return Macros[name]
end

function macrocall(m::Macro, args::String...; input::String="")::String
  if m.eval
    shell() do sh
      args = map(args) do arg
        read_sh(sh, "echo $arg")
      end
    end
  end

  res = m.func(args..., input=input)
  if m.meta
    shell() do sh
      res = read_sh(sh, res)
    end
  end
  
  return res
end



end
