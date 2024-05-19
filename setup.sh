#!/bin/bash
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sudo apt update && sudo apt upgrade -y
  sudo apt-get -y install ninja-build gettext cmake unzip curl wget nodejs npm tmux fd-find ripgrep jq stow
elif [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ $(command -v brew) == "" ]]; then
    echo "Installing Hombrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew update
  else
    echo "Updating Homebrew"
    brew update
  fi
  brew install gettext cmake unzip curl wget nodejs npm tmux ffind ripgrep jq stow
fi

mkdir -p ~/.config

(
  git clone -b v0.10.0 https://github.com/neovim/neovim
  cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
  cd ../
  rm -rf neovim
)

(
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --key-bindings --completion --update-rc
)

git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

stow -v --adopt -t $HOME home
~/.config/tmux/plugins/tpm/bin/install_plugins

chsh -s $(which zsh)
zsh -l
