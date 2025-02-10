export HISTORY_START_WITH_GLOBAL=true

pathmunge() {
    if ! echo $PATH | /usr/bin/env egrep -q "(^|:)$1($|:)"; then
        if [ "$2" = "after" ]; then
            PATH=$PATH:$1
        else
            PATH=$1:$PATH
        fi
    fi
}

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

[ -f ~/.lcl.zshenv ] && source ~/.lcl.zshenv

if [[ ! -v OVERRIDE_ZSH_CUSTOMIZATION ]]; then
    source ~/.zsh-catpuccin/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh
    export FZF_DEFAULT_OPTS=" \
      --color=bg+:#313244,bg:#0e0e1e,spinner:#f5e0dc,hl:#f38ba8 \
      --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
      --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

    export BAT_THEME="Catppuccin Mocha"
    export EZA_COLORS="$(vivid generate catppuccin-mocha)"
fi

pathmunge $HOME/local/bin
pathmunge $HOME/.local/bin
pathmunge $HOME/local/lib
CASE_SENSITIVE="true"
