module StartMacros
using  ..MacroDatabase
using  ..MacroExpander
using  ..ShellCompiler
using  ..ShellInterop
export add_macro

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
      fn = shellfunc(ARGS[i+1])
      i += 1
    elseif ARGS[i] == "-i"
      check_multiple_methods()
      fn = parse_shellfunc(name, ARGS[i+1])
      i += 1
    elseif ARGS[i] == "-j"
      jl = true
    elseif ARGS[i] == "-e"
      ev = true
    elseif ARGS[i] == "-m"
      mt = true
    else
      error("invalid argument $(ARGS[i])")
    end
    i += 1
  end

  if fn == nothing
    if input == ""
      error("no transformation methods specified")
    else
      fn = jl ? parse_juliafunc(name,input) : parse_shellfunc(name,input)
    end
  end

  Macros["@$name"] = Macro("@$name", fn, ev, mt)
  return ""
end
Macros["@macro"] = Macro("@macro", macro_maker, false, true)

function heredoc_dlm(name)
  replace(String(gensym("fxcrd_sh_julia_$name")), "#", "%")
end


function echo_code(ARGS...; input="")
  dlm = heredoc_dlm("code")
  if isempty(ARGS)
    return "cat - <<$dlm\n$input\n$dlm"
  elseif ARGS == ("-s",)
    return "cat - <<'$dlm'\n$input\n$dlm"
  else
    error("Invalid arguments to @code macro")
  end
end
Macros["@code"] = Macro("@code", echo_code, false, false)


function add_macro(str,input="")
  args = (x->x.token).(tokenize(str))
  macro_maker(args...,input=input)
end

module ShellEnv end

function parse_juliafunc(name,input)
  eval(ShellEnv, parse("""
    function $name(ARGS...; input="")
      $input
    end
  """))
end

function parse_shellfunc(name, f_input)
  expanded_input = compile_str(f_input)
  out = ShellCompiler.convert_to_julia(expanded_input)
  if out == nothing
    shell() do sh
      eval_sh(sh, "__fxcrd_MACROFUNC_$name(){\n$expanded_input\n}")
    end
    shellfunc("__fxcrd_MACROFUNC_$name")
  else
    return ShellEnv.eval(out)
  end
end

function shellfunc(name)
  function f(ARGS...; input="")::String
    dlm=heredoc_dlm("function")
    heredoc="<<'$dlm'\n$input\n$dlm"

    shell() do sh
      read_sh(sh, "$name $(ARGS...) $heredoc")
    end
  end
end

end
