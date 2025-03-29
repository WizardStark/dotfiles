#!/bin/bash
set -e

require() {
    command -v "${1}" &>/dev/null && return 0
    printf 'Missing required application: %s\n' "${1}" >&2
    return 1
}

if ! require brew; then
    echo "Installing Hombrew"
    export NONINTERACTIVE=1
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    brew update
else
    echo "Updating Homebrew"
    brew update
fi

if [[ "$OSTYPE" == "linux-gnu"* ]] && require apt; then
    sudo apt update
    sudo apt install -y zsh
    # install neovim dependencies
    # The dependencies break if on ubuntu and installed with brew, so here we use apt
    sudo apt-get install -y ninja-build gettext cmake unzip curl build-essential
else
    brew install zsh
    # install neovim dependencies
    brew install ninja cmake gettext curl unzip
fi

brew install wget nodejs npm tmux ffind ripgrep jq vivid bat eza zoxide git-delta stow

mkdir -p ~/.config

if ! require nvim; then
    (
        git clone --depth 1 -b v0.11.0 https://github.com/neovim/neovim
        cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo
        sudo make install
        cd ../
        rm -rf neovim
    )
fi

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

mv ~/.zshrc ~/.zshrc_old
stow -v --adopt -t $HOME home
git restore home/.zshrc

~/.config/tmux/plugins/tpm/bin/install_plugins

nvim --headless "+Lazy! sync" +qa

sudo chsh -s $(which zsh)
zsh -l
echo "Done!"
