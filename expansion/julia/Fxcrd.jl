#!/usr/bin/env julia

module Fxcrd

include("./Tokenize.jl")
include("./ShellCompiler.jl")
include("./MacroDatabase.jl")
include("./MacroExpander.jl")

import .MacroExpander.compile_str
import .MacroExpander.compile_io

end
