module ShellCompiler
  const CONVERT = Ref{Bool}(false)
  function convert_to_julia(input)
    CONVERT[] || return nothing

    top_tokens = TokenList(input)
  
    exprs = Any[]

    function push_expr(ex)
      push!(exprs, ex)
    end

    while !done(top_tokens)
      token, typ = get_token!(top_tokens)
      ex = noncontext_parse(token, typ, top_tokens)
      push_expr(ex)
    end

    try
      return :(
        function(ARGS...; input="")
          $(exprs...)
        end
      )
    catch
      return nothing
    end
  end

  function shwordsplit(x)
    "todo"
  end

  function noncontext_parse(token, typ, tokens)
    if token == "(" && typ == :normal
      tk1, tp1 = get_token!(tokens)
      subshell_parse(tk1, tp1, tokens)

    elseif token == "[" && typ == :normal
      tk1, tp1 = get_token!(tokens)
      test_expr_parse(tk1, tp1, tokens)

    elseif token == "\n" && typ == :normal
      nothing

    else
      arg = [Expr(:string)]
      argument_parse(token, typ, tokens, arg, false)
      command_parse(arg[1], tokens, (length(arg)>1 ? arg[2:end] : [])...)

    end
  end

  function double_quotes_parse(str)
    result = [Expr(:string)]
    tokens = TokenList(str)
    last_index = 0
    while !done(tokens)
      token, typ, index = get_token()

      if last_index != index-1
        push!(strexpr[end].args, str[last_index:index])
      end
      last_index = index+length(token)

      if first(token) == '$'
        substitution_parse(token, tokens, result, true)
      else
        push!(strexpr.args, token)
      end
    end
  end


  function argument_parse(token, typ, tokens, result, double_quoted)
    if typ == :double_quotes
      push!(result[end].args, double_quote_parse(token))

    elseif typ == :single_quotes
      push!(result[end].args, token)

    elseif length(token) > 1
      while length(token) > 1
        if token[1] == '$'
          token = name_substitution_parse(token, tokens, result, double_quoted)
        end
      end
    end 
  end

  function name_substitution_parse(token, tokens, result, double_quoted)
    t2 = token[2]

    if t2 in "\$!-#"
      push!(result[end].args, :(SHELL[$("\$$t2")]))
      return token[2:end]

    elseif t2 == "@"
      if double_quote
        push!(result[end].args, :(get(ARGS, 1, "")))
        push!(result, Expr(:..., :(length(ARGS) > 2 ? ARGS[2:end-1] : [])))
        push!(result, Expr(:string, :(get(ARGS, length(ARGS), ""))))
      else
        push!(result, :([$map($shwordsplit, ARGS)...;]...))
      end
      return token[2:end]

    elseif t2  == "*"
      if double_quote
        push!(result[end].args, :($join(ARGS, SHENV["IFS"])))
      else
        push!(result, :([$map($shwordsplit, ARGS)...;]...))
      end
      return token[2:end]

    elseif t2 == "#"
      push!(result[end].args, :($length(ARGS)))
      return token[2:end]

    elseif t2 == "0"
      push!(result[end].args, :(FILE["name"]))
      return token[2:end]

    elseif t2 in '1':'9'
      i = 2
      while i <= length(token) && token[i] in '1':'9'
        i = next(token,i)[2]
      end
      push!(result[end].args, :(ARGS[$(parse(Int, token[2:i-1]))]))
      return i == length(token) ? "" : token[next(token,i)[2]:end]

    else
      i = 2
      while i <= length(token) && isalnum(token[i])
        i = next(token,i)[2]
      end
      push!(result[end].args, :(SHENV[$(token[2:i])]))
      return i == length(token) ? "" : token[next(token,i)[2]:end]
    end
  end

  function command_parse(cmd, tokens, t1_args...)
    targs = []
    while !done(tokens) && !(peek_token(tokens)[1] in ("\n",";"))
      token, typ = get_token!(tokens)

      args = [Expr(:string)]
      argument_parse(token, typ, args, false)
      append!(targs, args)
    end

    :(FSHELL[$cmd](args..., $(targs...)))
  end
end
