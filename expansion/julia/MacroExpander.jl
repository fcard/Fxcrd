module MacroExpander
using  ..Fxcrd.MacroDatabase
using  ..Fxcrd.Tokenize
using  ..Fxcrd.ShellInterop
export MacroCall, analyze_line, compile_io, compile_str,
       ismacro, isend, ismultiline,
       nameof, preof, argsof, inputof

mutable struct MacroCall
  name::String
  pre::String
  args::Vector{String}
  input::String
  ismultiline::Bool

  MacroCall() = new("","",[],"",true)
end

ismacro(m::MacroCall) = m.name != "" && m.name != "@end"
ismultiline(m::MacroCall) = m.ismultiline
preof(m::MacroCall) = m.pre
nameof(m::MacroCall) = m.name
argsof(m::MacroCall) = m.args
inputof(m::MacroCall) = m.input
isend(m::MacroCall) = m.name == "@end"

function compile_io(io)
  compile_lines(readlines(io))
end

function compile_str(str)
  compile_lines(split(str, "\n"))
end

function compile_lines(lines)
  i = 1
  output = String[]
  gotmacro = false
  evaluate = false

  while i <= length(lines)
    m, i = read_macrocall(lines, i)
    if ismacro(m)
      ex = expand_macro(m)
      !isempty(ex) && append!(output, split(ex,"\n"))
      gotmacro = true
    else
      push!(output, lines[i])
      i += 1
    end
  end

  if gotmacro
    outstr = compile_lines(output)
  else
    outstr = join(output, "\n")
  end
  return outstr
end

function expand_macro(mcall)
  m = get_macro(mcall.name)
  return macrocall(m, mcall.args..., input=mcall.input)
end

function read_macrocall(lines, i)
  m = analyze_line(lines[i])
  if ismacro(m)
    if ismultiline(m)
      indent=""
      minput = String[]
      nested = 1
      ml = nothing
      while nested > 0
        @assert i < length(lines) "closing @end not found after multiline macro call ($m, $ml)"
        i += 1
        line = lines[i]
        ml = analyze_line(line)
        if ismacro(ml)
          if ismultiline(ml)
            nested += 1
          end
          push!(minput, line)
        elseif isend(ml)
          @assert argsof(ml) == [] && inputof(ml) == "" "other code alongside @end is not allowed"
          nested -= 1
          nested == 0 || push!(minput, line)
          nested == 0 && (indent = " "^(findfirst(line, '@')-1))
        else
          push!(minput, line)
        end
      end
      m.input = join(map(ln->remove_indent(indent,ln), minput),"\n")
    end
    i += 1
  end
  return m, i
end

function remove_indent(indent, line)
  if startswith(line, indent)
    indent != "" && (line = line[length(indent):end])
    if startswith(line, "  ")
      return line[3:end]
    else
      return line
    end
  else
    return line
  end
end

function analyze_line(line)
  tokens = tokenize(line)
  state = :pre
  macrocall = MacroCall()

  for t in tokens
    if state == :pre
      if t.typ == :macro
        macrocall.name = t.token
        macrocall.pre  = line[1:t.index-1]
        state = :args
      else
        pre_index = t.index
      end
    elseif state == :args
      if t.typ == :macromma
        macrocall.input = line[t.index+2:end]
        macrocall.ismultiline = false
        break
      else
        push!(macrocall.args, t.token)
      end
    end
  end

  return macrocall
end
end
