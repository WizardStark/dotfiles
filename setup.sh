#!/bin/bash
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  sudo apt update && sudo apt upgrade -y
  sudo apt-get -y install ninja-build gettext cmake unzip curl wget nodejs npm tmux fd-find ripgrep jq stow

  (
    wget "https://github.com/sharkdp/bat/releases/download/v0.24
.0/bat-musl_0.24.0_amd64.deb"
    sudo dpkg -i bat-musl_0.24.0_amd64.deb
    rm bat-musl_0.24.0_amd64.deb
  )

  (
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
  )

  (
    wget "https://github.com/sharkdp/vivid/releases/download/v0.9.0/vivid-musl_0.9.0_amd64.deb"
    sudo dpkg -i vivid-musl_0.9.0_amd64.deb
    rm vivid-musl_0.9.0_amd64.deb
  )

elif [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ $(command -v brew) == "" ]]; then
    echo "Installing Hombrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew update
  else
    echo "Updating Homebrew"
    brew update
  fi
  brew install gettext cmake unzip curl wget nodejs npm tmux ffind ripgrep jq stow vivid bat eza
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

git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

stow -v --adopt -t $HOME home
~/.config/tmux/plugins/tpm/bin/install_plugins

chsh -s $(which zsh)
zsh -l
