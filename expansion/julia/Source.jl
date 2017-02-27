module Source
using  ..MacroDatabase
using  ..MacroExpander
using  ..ShellInterop
export source

const Included=Set{String}()
const Compiled=Set{String}()

const COMPILED_PATH = "$FXCRD_PATH/compiled"

function compiled_path(file)
  return "$(COMPILED_PATH)/$(replace(file, "/", "%%"))"
end

function outdated(file)
  return mtime(file) > mtime(compiled_path(file))
end


function source(files...; force=false)
  for file in files
    if force || !(file in Included)
      push!(Included, file)
      if !(file in Compiled) && (force || outdated(file))
        compiled = compile_io(file)
        open(compiled_path(file), "w") do cfile
          println(cfile, compiled)
        end
      end
    end
  end
end

function source_force(ARGS...; input="")
  source(ARGS..., force=true)
  return ""
end


MacroDatabase.Macros["@source"]=Macro("@source", source_force, true, true)

end
