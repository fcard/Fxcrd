module Types
export TokenBuilder, Token, TokenList, Macro, MacroCall

mutable struct TokenBuilder
  typ::Symbol
  start_index::Int
  end_index::Int
  token::Vector{Char}

  TokenBuilder() = new(:none, 1, 1, [])
end

struct Token
  token::String
  typ::Symbol
  index::Int

  function Token(tb::TokenBuilder)
    token = String(tb.token)
    new(token, tb.typ, tb.start_index)
  end
end

struct TokenList
  tokens::Vector{Token}
  i::Int

  TokenList(str::String) = new(tokenize(str), 1)
  function TokenList(tl::TokenList, dlm::String)
    new(view(tl.tokens, tl.i:(findnext(tl.tokens, dlm, tl.i)-1)), 1)
  end
end
peek_token(tl::TokenList) = (t=tl.tokens[tl.i]; (t.token, t.typ, t.index))
get_token!(tl::TokenList) = (t=peek_token(tl); tl.i+=1; t)

Base.done(tl::TokenList)   = tl.i > length(tl.tokens)
Base.length(tl::TokenList) = length(tl.tokens)

struct Macro
  name::String
  func::Function
  eval::Bool
  meta::Bool
end

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

end
