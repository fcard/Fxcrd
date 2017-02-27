#!/bin/sh


echo "Hello and welcome to my messy shell macro system."
echo "I need a executable visible in your PATH so that helps me localize my files."
echo "Where can I put it? type nothing and I will try /usr/local/bin."

Here="$(readlink -m "$(dirname $0)")"
Attempts=0
InstallDir="/usr/local/bin"
FoundDir=""
pick_directory() {
  local GotItRight=false
  while ! $GotItRight; do
    read -r maybe_dir
    if [ -z "$maybe_dir" ]; then
      echo "$InstallDir it is..."
      maybe_dir="$InstallDir"
    fi
    if [ ! -d "$maybe_dir" ]; then
      echo "That's not a directory!"
      Attempts=$((Attempts+1))
    elif [ ! -w "$maybe_dir" ]; then
      echo "You can't put it there! Try again with sudo maybe?"
      Attempts=$((Attempts+1))
    else
      FoundDir="$maybe_dir"
      GotItRight=true
      echo "Well done!!!! Congrats"
      echo
    fi
  done
}

FirstTry=true
while [ -z "$(command -v fxcrd_path)" ]; do
  FirstTry=false
  pick_directory
  ln -s "$Here/tools/fxcrd_path" "$FoundDir/fxcrd_path"
  if [ -n "$(command -v fxcrd_path)" ]; then
    InstallDir="$FoundDir"
    printf "That went well!"
    for i in $(seq 1 $Attempts); do
      printf "!"
    done
    echo
  else
    echo "I can't find the executable! What the..."
    echo "I am taking it back."
    rm "$FoundDir/fxcrd_path"
    Attempts=$((Attempts+1))
  fi
done

if $FirstTry; then
  sleep 5
  echo
  echo
  echo "...Oh you got it already? Well done!"
  InstallDir="$(dirname "$(command -v fxcrd_path)")"
fi
if [ "$Attempts" -gt 6 ]; then
  echo "What an adventure! Now for the next part..."
  echo
fi
echo "There are two backends to the macro expander, a Julia version (v0.6+)"
echo "or a posix shell version. The first has a cool interactive mode and is"
echo "much much faster. Which one do you want? (j/s)"

ManagedToPick=false
Julia=undecided

while ! $ManagedToPick; do
  read -r answer
  case "$answer" in
    [jJ]) Julia=true ;;
    [sS]) Julia=false ;;
    *)
      echo "???"
      Attempts=$((Attempts+1))
      ;;
  esac
  if [ ! "$Julia" = undecided ]; then
    if $Julia; then
      if [ -z "$(command -v julia)" ]; then
        echo "I can't find julia!! Maybe adjust your PATH or"
        echo "pick the other option."
        Attempts=$((Attempts+1))
      else
        if $(julia -E 'VERSION > v"0.6-dev"'); then
          echo "Seems like you're almost ready"
          echo "I need to install two other executables, where do you want"
          echo "they to go? type nothing and it will be '$InstallDir'"
          pick_directory
          InstallDir="$FoundDir" 
          SuccessLinking=true
          ln -s "$Here/expansion/julia/bin/fxcrd_source" "$InstallDir/fxcrd_source" || 
            SuccessLinking=false
          ln -s "$Here/expansion/julia/bin/fxcrd_i" "$InstallDir/fxcrd_i" ||
            SuccessLinking=false
          ln -s "$Here/tools/fxcrd_compile" "$InstallDir/fxcrd_compile" ||
            SuccessLinking=false
            
          if ! $SuccessLinking; then
            echo "Huh?? Did something happen? (y/n)"
            Answer=""
            while ! echo "$Answer" | grep -E "[yYnN]"; do
              read -r Answer
              case "$Answer" in
                [yY])
                  echo "What the... Well, back to square zero+1. Which version? (j/s)"
                  Attempts=$((Attempts+1))
                  ;;
                [nN])
                  echo "Hmmm, okay, don't blame me if things blow up."
                  ManagedToPick=true
                  ;;
                *)
                  echo "bluh"
                  ;;
              esac
            done
          else
            echo "Oh, it worked!"
            ManagedToPick=true
          fi
        else
          echo "But you don't have a high enough version of julia!!"
          echo "Try again... Which version?"
          Attempts=$((Attempts+1))
        fi
      fi
    else
      echo "Oh, you're all set then."
      echo
      ManagedToPick=true
    fi
  fi
done
sleep 5
echo "Congratulations, you won!! Your score is $((10000-Attempts))."
echo "Source '$(fxcrd_path)/init' in your .*rc file to start using"
echo "Fxcrd. Put your fxcrd code files in '$(fxcrd_path)/include' and"
echo "they will be automatically compiled and sourced."
echo "Run fxcrd_i to start a interactive session!"
echo
echo "good bye..."

exit 0
