module MacroDatabase
using ..Fxcrd.ShellCompiler
export Macro, get_macro, add_macro

struct Macro
  name::String
  func::Function
  eval::Bool
  meta::Bool
end
const Macros = Dict{String,Macro}()

module ShellEnv end

function macro_maker(ARGS...; input="")
  name = ARGS[1]

  i  = 2
  ev = false
  mt = false
  fn = nothing
  jl = false

  only_one_error = "a macro can only have one transformation method"
  function check_multiple_methods()
    @assert input == "" && fn == nothing && !jl only_one_error
  end

  while i <= length(ARGS)
    if ARGS[i] == "-f"
      check_multiple_methods()
      fn = shellfunc(args[i+1])
    elseif ARGS[i] == "-i"
      check_multiple_methods()
      fn = parse_shellfunc(args[i+1])
    elseif ARGS[i] == "-j"
      jl = true
    elseif ARGS[i] == "-e"
      ev = true
    elseif ARGS[i] == "-m"
      mt = true
    else
      error("invalid argument $(args[i])")
    end
  end

  if fn == nothing
    if input == ""
      error("no transformation methods specified")
    else
      fn = jl ? parse_juliafunc(name,input) : parse_shellfunc(input)
    end
  end

  Macros["@$name"] = Macro("@$name", fn, ev, mt)
  return ""
end
Macros["@macro"] = Macro("@macro", macro_maker, false, true)

function get_macro(name)
  @assert haskey(Macros, name) "macro $name not defined"
  return Macros[name]
end

function add_macro(str,input="")
  args = (x->x.token).(tokenize(str))
  macro_maker(args...,input=input)
end



function parse_juliafunc(input)
  ShellEnv.eval(parse(
    "function (args...; input="")
       $input
     end"
  ))
end

function parse_shellfunc(f_input)
  out = ShellCompiler.convert_to_julia(f_input)
  if out == nothing
    return function f(ARGS...; input="")
      cmd = `sh -c  "$f_input" macro_expansion $(ARGS...)`
      println(cmd)
      readstring(cmd)
    end
  else
    return ShellEnv.eval(out)
  end
end

end
