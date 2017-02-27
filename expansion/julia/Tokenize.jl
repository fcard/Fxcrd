module Tokenize
export TokenBuilder, Token, TokenListtokenize, tokenize

mutable struct TokenBuilder
  typ::Symbol
  start_index::Int
  end_index::Int
  token::Vector{Char}
  incomplete::Bool

  TokenBuilder() = new(:none, 1, 1, [], false)
end

struct Token
  token::String
  typ::Symbol
  index::Int
  incomplete::Bool

  function Token(tb::TokenBuilder)
    token = String(tb.token)
    new(token, tb.typ, tb.start_index, tb.incomplete)
  end

  function Token(t::Token;
     token=t.token, typ=t.typ, index=t.index, incomplete=t.incomplete)

    new(token, typ, index, incomplete)
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


function tokenize(line; incomplete=:notreally)
  tokens = Token[]
  escape = false
  token_builder = TokenBuilder()
  next_index = 1

  if incomplete in (:single_quotes, :double_quotes)
    token_builder.typ = incomplete
    token_builder.incomplete = true
  end

  function build(completes=false)
    completes && ( token_builder.incomplete = false )
    !istype(:none) && push!(tokens, Token(token_builder))
    token_builder.typ   = :none
    token_builder.token = Char[]
    token_builder.incomplete = false
  end

  function push_token(c)
    push!(token_builder.token, c)
  end

  function last_char()
    token_builder.token[end]
  end

  istype(t, ts...) = token_builder.typ == t || istype(ts...)
  istype() = false

  function newtype(t)
    if istype(:none)
      token_builder.start_index = token_builder.end_index
    end
    token_builder.typ = t
  end

  function next_char(c)
    token_builder.end_index += sizeof(string(c))
  end

  function isincomplete()
    token_builder.incomplete = true
  end

  next_index = 1
  for c in line
    @label loop_start

    if escape
      push!(token_builder.token, c)
      istype(:none) && newtype(:normal)
      escape = false
    elseif istype(:ambiguous_special)
      if c == last_char()
        push_token(c)
        newtype(:special)
        build()
      else
        newtype(:special)
        build()
        @goto loop_start
      end
    elseif c == '\\' && !istype(:single_quotes)
      escape = true
    elseif c == '@' && istype(:none)
      newtype(:macro)
      push_token(c)
    elseif c == '@' && istype(:macro)
      newtype(:macromma)
      push_token(c)
      build()
    elseif c == '"'
      istype(:single_quotes) ? push_token(c) : 
      istype(:double_quotes) ? build(true)   :     
      (build(); newtype(:double_quotes); isincomplete())
    elseif c == '\''
      istype(:double_quotes) ? push_token(c) :
      istype(:single_quotes) ? build(true)   :
      (build(); newtype(:single_quotes); isincomplete())
    elseif c == ' ' && !istype(:single_quotes, :double_quotes)
      build()
    elseif c in "(){}[]<>;\n" && !istype(:single_quotes, :double_quotes)
      build()
      newtype(:special)
      push_token(c)
      build()
    elseif c in "&|" && !istype(:single_quotes, :double_quotes)
      build()
      newtype(:ambiguous_special)
      push_token(c)

    elseif istype(:none)
      newtype(:normal)
      push_token(c)
    else
      push_token(c)
    end
    next_char(c)
  end
  build()

  return tokens
end

end
