#!/bin/bash
directory=$(pwd)
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

cd

sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.5/zsh-in-docker.sh)" -- \
  -t "jonathan" \
  -p git \
  -p fzf \
  -p sudo \
  -p https://github.com/zsh-users/zsh-autosuggestions \
  -p https://github.com/zsh-users/zsh-syntax-highlighting

mkdir -p ~/.config
cd "$directory"
rm ~/.zshrc
cp .zshrc ~/.zshrc

cd
git clone -b v0.9.5 https://github.com/neovim/neovim
cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo
sudo make install
cd ../
rm -rf neovim

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --key-bindings --completion --update-rc

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit*

git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

cd "$directory"
stow --adopt -t $HOME .
~/.config/tmux/plugins/tpm/bin/install_plugins

chsh -s $(which zsh)
exec $SHELL
