export ZSH="$HOME/.oh-my-zsh"

append_path()
{
  if ! eval test -z "\"\${$1##*:$2:*}\"" -o -z "\"\${$1%%*:$2}\"" -o -z "\"\${$1##$2:*}\"" -o -z "\"\${$1##$2}\"" ; then
    eval "$1=\$$1:$2"
  fi
}

prepend_path()
{
  if ! eval test -z "\"\${$1##*:$2:*}\"" -o -z "\"\${$1%%*:$2}\"" -o -z "\"\${$1##$2:*}\"" -o -z "\"\${$1##$2}\"" ; then
    eval "$1=$2:\$$1"
  fi
}

prepend_path $HOME/local/bin $PATH
prepend_path $HOME/.local/bin $PATH
prepend_path $HOME/local/lib $LD_LIBRARY_PATH
prepend_path $HOME/local/share/man $MANPATH
ZSH_THEME="jonathan"
CASE_SENSITIVE="true"
HIST_STAMPS="mm/dd/yyyy"

VI_MODE_SET_CURSOR=true
bindkey -M viins 'jf' vi-cmd-mode

plugins=(git
  vi-mode
  zsh-syntax-highlighting
  zsh-autosuggestions
  sudo
  fzf)

source $ZSH/oh-my-zsh.sh
export EDITOR='nvim'
alias vim="nvim"
alias cl="printf '\33c\e[3J'"
alias src='source ~/.zshrc'
alias erc='vim ~/.zshrc'
alias pls='sudo $(fc -ln -1)'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.lcl.zsh ] && source ~/.lcl.zsh
