# Fxcrd

I was sick and bored and I don't care god

It took me three days to realize that the name was just my username with a x in it minus a letter.
whatever it worked for linus

I will eventually make this less of a mess. Hopefully.

# Install

Clone this somewhere.
```sh
$ git clone https://github.com/fcard/Fxcrd
```
Use the install.sh, it's interactive and obnoxious.
```sh
$ ./install.sh
Welcome and blah blah I will ask a few questions and we will install this thing
But wait there's more!
```
The above does only a half assed job and you need to add this to your .zshrc/.bashrc whatever
```sh
. $(fxcrd_path)/init
```
I think that's it but I don't know.
Also don't move the cloned directory anywhere else or everything will break.

Oh yeah, there are two backends for the macro expander, a slow and probably buggy `sh` one, and 
a `julia` one which I spent most of my time on. I suggest the latter but you need `julia 0.6` which isn't
even out yet. Good. (install.sh will ask you which you want)

Next time I get a cold I will probably add more backends.

# Compiling

Put your code files in the `include` directory and they will be compiled next time you open your shell.
If you installed the julia backend you can also do:
```
$ $(fxcrd_path)/compile "/path/to/file"
```
I don't remember how you do that with the `sh` backend I will edit this in later.
Compiled files will be put in the `compiled` directory and will be loaded automatically.

# The code files an their macros

Code files are just shell scripts but you can do
```
@macro name
  @code
    echo $1
  @end
@end

@name 1 @@
```
and that will compile to
```sh
echo 1
```

`$(fxcrd_path)/include/local_function`:
```sh

@macro local_function
  local name=$1
  local body="$(cat)"
  
  local prefix="$(</dev/urandom tr -cd '[:alnum:]' | head -c 32)"
  
  @code
    __${prefix}__${name}(){
      $body
    }
    local $name="__${prefix}__${name}"
  @end
@end

f() {
  @local_function g
    echo $1
  @end
  
  $g 10
}

f
#g ins't here that's the point of the example
```

`$(fxcrd_path)/compiled/<some_giberish>%%local_function`:
```sh
f() {
__kqhqAl2r2qkyx58LV3aQjtuEhcJjS8Ap__g(){
   echo $1
}
local g="__kqhqAl2r2qkyx58LV3aQjtuEhcJjS8Ap__g"
  
  $g 10
}

f
#g ins't here that's the point of the example
```

```sh
$ sh $(fxcrd_path)/compiled/<some_giberish>%%local_function
10
```
Ya get the idea?

There are two types of macro calls:
```sh
@name arg1 arg2 arg3 @@everything here will be read as input.
```
```sh
@name arg1 arg2 arg3
  every here
  will be read
  as input
  you fool
@end
```
Some indentation shenanigans going on in the multiline form
```
@macro name @@echo $(cat)

@name
  10
@end
```
becomes:
```
10
```
instead of:
```
  10
```
And that's about it.

Oh yeah, `fxcrd_i` starts an interactive session: (needs julia)
```sh
[fabio:...ripts/ShellExtensions/fxcrd]$ fxcrd_i                                         (master) 

  ------------------
   --- hello !! --- 
  ------------------

[---]==> echo 10
|/
| 10
|\
[---]==> @macro m
[---] >>   echo "echo 10"
[---] >> @end
[---]==> @m @@
|/
| 10
|\
[---]==> .expand
[e--]==> @m @@
|/
| echo 10
|\
[e--]==> .help
  .q | .quit       == end session
  .e | .expand     == toggles if macros are expanded or evaluated
  .t | .token      == shows tokens of input line
  .c | .call       == shows macrocall analysis
  .l | .list       == list macros
  .s | .stacktrace == show last stacktrace from a julia error
  .h | .help       == this help text

[e--]==> .quit
 bye bye!
 
[fabio:...ripts/ShellExtensions/fxcrd]$ echo I was in a better mood when I made it      (master) 
I was in a better mood when I made it
```
There was also a thing where if you had the julia backend you use you could create macros with julia code
```
@macro jlm -j
  println("echo 10")
@end
```
But there is some weird shit about "world age" in the error messages and I need some sleep
