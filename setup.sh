sudo apt update && sudo apt upgrade -y
sudo apt-get -y install ninja-build gettext cmake unzip curl wget nodejs npm tmux fd-find ripgrep

sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.5/zsh-in-docker.sh)" -- \
    -t "jonathan" \
    -p git \
    -p fzf \
    -p sudo \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/zsh-users/zsh-syntax-highlighting

git clone git@github.com:neovim/neovim.git
cd neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo
sudo make install
cd ../
rm -rf neovim

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin

git clone https://github.com/WizardStark/dotfiles
cd dotfiles
sh sync.sh nvim r
sh sync.sh tmux r
cp .zshrc ~/.zshrc
source ~/.zshrc

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

tmux new-session -d -s setup_session 'tmux source ~/.config/tmux/tmux.conf'
chmod +x ~/.config/tmux/plugins/tpm/scripts/install_plugins.sh
sh ~/.config/tmux/plugins/tpm/scripts/install_plugins.sh
