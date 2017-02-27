module Interactive
using  ..ShellInterop
using  ..MacroExpander
using  ..MacroDatabase
using  ..Tokenize

mutable struct InteractConfig
  expand::Bool
  tokens::Bool
  macrocall::Bool
  quit::Bool
  stacktrace::StackTrace

  InteractConfig() = new(false,false,false,false,[])
end

mutable struct InputState
  top::Bool
  topmacro::Bool
  incomplete_string::Bool
  incomplete_parens::Bool
  escaped_newline::Bool
  nested_macros::Int
  parens_balance::Vector{String}
  quotes_incomplete::Symbol
  found_macro::Bool

  InputState() = new(true,true,false,false,false,0,[],:none,false)
end

macro with(change, actions)
  changed  = change.args[1]
  newvalue = change.args[2]
  quote
    oldvalue = $(esc(changed))
    $(esc(changed)) = $newvalue
    $(esc(actions))
    $(esc(changed)) = oldvalue
  end
end

macro toggle(x)
  esc(:($x=!$x))
end

function main_loop(shell)
  config = InteractConfig()

  while !config.quit
    try
      input = obtain_input(config, InputState())
      local output
      if !config.quit
        if config.expand
          output = input
        else
          output = read_sh(shell, input)
        end
        if output != ""
          pre="| "
          output = "|/\n$pre"*join(split(output,"\n"),"\n$pre")*"\n|\\"
          println(output)
        end
      end
    catch err
      print_with_color(:red, sprint(showerror, err), "\n")
      config.stacktrace = stacktrace()
      println()
    end
  end
end

function obtain_input(config::InteractConfig,is::InputState)::String
  print_prompt(config, is)
  input = readline()

  process_input(input, config, is)
end

function process_input(input, config::InteractConfig, is::InputState)::String
  next_line() = obtain_input(config,is)

  if is.incomplete_string
    tokens = tokenize(input, incomplete=is.quotes_incomplete)
    if isempty(tokens)
      return "\n$(next_line())"
    elseif length(tokens) == 1
      t = tokens[1]
      is.incomplete_string = t.incomplete
      is.quotes_incomplete = t.incomplete ? t.typ : :none
      return "$input\n$(t.incomplete ? next_line() : "")"
    else
      is.incomplete_string = false
      is.quotes_incomplete = :none

      t = tokens[1]
      i = t.index+length(t)+2

      incput = input[1:i-1]
      comput = input[i:end]

      return "$incput$(process_input(comput,config,is))"
    end

  elseif is.top && is_magic_command(input)
    exec_magic(input, config)
  else
    ma = macro_analysis = analyze_line(input)
    print_extra_info(config, input, macro_analysis)
   
    if ismacro(ma) && ismultiline(ma)
      is.nested_macros += 1
      is.found_macro = true
    elseif isend(ma) && is.nested_macros > 0
      is.nested_macros -= 1
    end

    if is.nested_macros > 0
       @with is.topmacro = false begin
         result = "$input\n$(next_line())"
       end
       
       return is.topmacro ? compile_str(result) : result
    else
      if is.found_macro
        if isend(macro_analysis)
          return input
        else
          return "$input\n$(next_line())"
        end

      else
        if ismacro(macro_analysis) # single line macro
          return compile_str(input)

        elseif endswith(input, "\\")
          is.escaped_newline = true
          return "$input\n$(next_line())"
        
        else
          check_balance(input, is)
          if is.incomplete_parens || is.incomplete_string
            return "$input\n$(next_line())"
          else
            return input
          end
        end
      end
    end
  end
end

cute_invert_lparen(p) = (s="-()-{}-[]-")[search(s,p)+1] # swoooon
cute_invert_rparen(p) = (s="-()-{}-[]-")[search(s,p)-1] # this code is so cute !!

invert_parens(x) =
  contains("([{", x) ? cute_invert_lparen(x) : cute_invert_rparen(x)

isparens(t::Token) = t.typ == :special && contains("(){}[]", t.token)

function check_balance(input::String, is::InputState)
  input_tokens = tokenize(input, incomplete=is.quotes_incomplete)
  if !isempty(input_tokens) && last(input_tokens).incomplete
    is.quotes_incomplete = last(input_tokens).typ
  end

  for t in filter(isparens, input_tokens)
    current_parens = t.token

    if contains("([{", current_parens)
      push!(is.parens_balance, current_parens)

    else
      if isempty(is.parens_balance)
        error("Unmatched parens '$p'")

      elseif last(is.parens_balance) == invert_parens(current_parens)
        pop!(is.parens_balance)

      else
        error("Wrong matching parens: '$(last(is.parens_balance))$current_parens'")
      end
    end
  end
  is.incomplete_parens = !isempty(is.parens_balance)

  if !isempty(input_tokens)
    lt = last(input_tokens)
    if lt.incomplete
      is.incomplete_string = true
      is.quotes_incomplete = lt.typ
    end
  end
end

function print_prompt(config::InteractConfig, is::InputState)
  print_with_color(
    prompt_color(config),
    string(prompt_container_thingy(config), prompt_arrow(is)," "),
    bold=true
  )
end

function prompt_container_thingy(config::InteractConfig)
  e = config.expand    ? 'e' : '-'
  t = config.tokens    ? 't' : '-'
  m = config.macrocall ? 'm' : '-'

  return "[$e$t$m]"
end

function prompt_arrow(is::InputState)
  is.incomplete_string  ? " '>" :
  is.incomplete_parens  ? "()>" :
  is.escaped_newline    ? "//>" :
  is.nested_macros != 0 ? " >>" :
  true && true || true  ? "==>" : ""
end

function prompt_color(config::InteractConfig)
  config.expand ? :green : :red
end

function is_magic_command(input)
  startswith(input, ".")
end

function exec_magic(input, config::InteractConfig)::String
  iscommand(cmd) = input in (".$cmd", ".$(cmd[1])")

  if iscommand("quit")
    config.quit = true

  elseif iscommand("expand")
    @toggle config.expand

  elseif iscommand("call")
    @toggle config.macrocall

  elseif iscommand("token")
    @toggle config.tokens

  elseif iscommand("list")
    for (m,f) in Macros
      println("-- $m")
    end
    
  elseif iscommand("stacktrace")
    display(config.stacktrace)
    println()

  elseif iscommand("help")
    println("""
      .q | .quit       == end session
      .e | .expand     == toggles if macros are expanded or evaluated
      .t | .token      == shows tokens of input line
      .c | .call       == shows macrocall analysis
      .l | .list       == list macros
      .s | .stacktrace == show last stacktrace from a julia error
      .h | .help       == this help text
    """)

  else
    print_with_color(:red, "invalid fxcrd_i command $input. See '.help'\n")

  end
  return ""
end

function print_extra_info(config,input,mm)
  if config.tokens
    print_with_color(:yellow, "[t~~] ")
    for t in tokenize(input)
      print("('$(t.token)'::$(t.typ)) ")
    end
    println()
  end
  if !ismultiline(mm) && ismacro(mm) && config.macrocall
    function pm(s)
      print_with_color(:red, "[~c~]")
      println(s)
    end

    pm("name=$(mm.name)")
    pm("args=$(join(mm.args, " "))")
    pm("input ----------")
    pm("----------------")
    println(mm.input)
    pm("---------------")
  end
end
    

end
