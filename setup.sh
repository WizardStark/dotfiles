#!/bin/bash
set -e

sudo echo "Shell elevated with su permissions"

require() {
    command -v "${1}" &>/dev/null && return 0
    printf 'Missing required application: %s\n' "${1}" >&2
    return 1
}

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # install linuxbrew dependencies
    # these need to be installed with apt to allow installation of brew
    if require apt; then
        sudo apt update
        sudo apt-get install -y build-essential procps curl file git
    elif require yum; then
        sudo yum groupinstall 'Development Tools'
        sudo yum install procps-ng curl file git
    fi
fi

if ! require brew; then
    echo "Attempting to configure Homebrew from standard locations..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    if ! require brew; then
        echo "Installing Homebrew..."
        export NONINTERACTIVE=1
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if [ -f "/opt/homebrew/bin/brew" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [ -f "/usr/local/bin/brew" ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
    fi
fi

brew install bat dust eza ffind git-delta hyperfine jq jupytext nodejs npm nvim ripgrep stow tmux tokei uv vivid wget zoxide zsh
npm install -g tree-sitter-cli
uv tool install neovim-remote

mkdir -p ~/.config

(
    git clone https://github.com/catppuccin/zsh-syntax-highlighting.git ~/.zsh-catpuccin
)

(
    mkdir -p "$(bat --config-dir)/themes"
    wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme
    bat cache --build
)

(
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --key-bindings --completion --update-rc
)

(
    git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
)

echo "Moving existing ~/.zshrc to ~/.zshrc_old"
mv ~/.zshrc ~/.zshrc_old
stow -v --adopt -t $HOME home

~/.config/tmux/plugins/tpm/bin/install_plugins

nvim --headless "+Lazy! sync" +qa

command -v zsh | sudo tee -a /etc/shells
sudo chsh -s $(which zsh) $(whoami)
zsh -l
echo "Done!"
