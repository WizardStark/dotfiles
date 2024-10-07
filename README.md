## WizardStark's dotfiles

This is a collection of configuration files for the tools that I like to use
during software development: NeoVim, Tmux (not so much anymore due to Neovide and my homegrown session management), Alacritty.

## Dotfile management

This project uses [GNU Stow](https://www.gnu.org/software/stow/) to create symlinks
from this repository to your $HOME directory.

## Setup

NOTE:

- This script requires sudo permissions
- This script will create symlinks to ~/.zshrc, ~/.config/nvim and ~/.config/tmux,
  see [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html#Conflicts) for how conflicts will be handled

```bash
git clone https://github.com/WizardStark/dotfiles.git
cd dotfiles
chmod +x setup.sh
./setup.sh
```

If on an Apple Silicon device, after running `nvim` once, also
run the following to recompile the broken plugin:

```bash
cd ~/.local/share/nvim/lazy/telescope-fzf-native.nvim &&
cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release &&
cmake --build build --config Release &&
cmake --install build --prefix build &&
cd -
```

## Notes for tweaking

The best sources to consult for understanding the nvim config:

- [Lazy.nvim](https://github.com/folke/lazy.nvim) - Plugin manager
- [Legendary.nvim](https://github.com/mrjones2014/legendary.nvim) - Command palette

## Usage
The most important keybinds are `<space><space>` in NeoVim for the command palette,
wherein you can fuzzy find your way through most available commands, and `<C-a>?` for
a list of tmux binds - this is much less nice to use as I have not found a way to add
descriptions, but the commands are pretty self explanatory.
