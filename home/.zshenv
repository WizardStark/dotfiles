export ZSH="$HOME/.oh-my-zsh"
export ZSH_THEME="catpuccin"

pathmunge() {
  if ! echo $PATH | /usr/bin/env egrep -q "(^|:)$1($|:)"; then
    if [ "$2" = "after" ]; then
      PATH=$PATH:$1
    else
      PATH=$1:$PATH
    fi
  fi
}

[ -f ~/.lcl.zshenv ] && source ~/.lcl.zshenv

pathmunge $HOME/local/bin
pathmunge $HOME/.local/bin
pathmunge $HOME/local/lib
CASE_SENSITIVE="true"
