export ZSH="$HOME/.oh-my-zsh"
export PATH=$HOME/local/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export LD_LIBRARY_PATH=$HOME/local/lib:$LD_LIBRARY_PATH
export MANPATH=$HOME/local/share/man:$MANPATH
export LC_ALL=en_IN.UTF-8
export LANG=en_ING.UTF-8
ZSH_THEME="jonathan"
CASE_SENSITIVE="true"
HIST_STAMPS="mm/dd/yyyy"

plugins=(git
  zsh-syntax-highlighting
  zsh-autosuggestions
  sudo
  fzf
  zsh-vi-mode)

source ~/.zsh-vi-mode
source $ZSH/oh-my-zsh.sh
export EDITOR='nvim'
alias vim="nvim"
alias cl="printf '\33c\e[3J'"
alias s='source ~/.zshrc'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [ -f ~/.amazon.zsh ]; then
  source ~/.amazon.zsh
fi
