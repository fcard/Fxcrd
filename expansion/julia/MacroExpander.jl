module MacroExpander
using  ..Fxcrd.MacroDatabase
using  ..Fxcrd.Tokenize
export MacroCall, compile_io, compile_str

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

  while i <= length(lines)
    m, i = read_macrocall(lines, i)
    if ismacro(m)
      ex = expand_macro(m)
      !isempty(ex) && push!(output, ex)
      gotmacro = true
    else
      push!(output, lines[i])
      i += 1
    end
  end

  outstr = join(output, "\n")
  if gotmacro
    outstr = compile_str(outstr)
  end
  return outstr
end

function expand_macro(mcall)
  @assert haskey(MacroDatabase.Macros, mcall.name) "macro $(mcall.name) not defined"
  m = get_macro(mcall.name)
  return m.func(mcall.args...,input=mcall.input)
end

function read_macrocall(lines, i)
  m = analyze_line(lines[i])
  if ismacro(m)
    if ismultiline(m)
      minput = String[]
      nested = 1
      while nested > 0
        @assert i < length(lines) "closing @end not found after multiline macro call"
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
        else
          push!(minput, line)
        end
      end
      m.input = join(minput,"\n")
    end
    i += 1
  end

  return m, i
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
