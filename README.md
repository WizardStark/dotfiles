## WizardStark's dotfiles

This is a collection of configuration files for the tools that I like to use
during software development: Neovim, Tmux (not so much anymore due to Neovide and my homegrown session management), Alacritty.

## Dotfile management

This project uses [GNU Stow](https://www.gnu.org/software/stow/) to create symlinks
from this repository to your $HOME directory.

## Setup

NOTE:

- This script will ask for sudo permissions, which are then used for brew and apt (if applicable) installs
- This script will create symlinks to ~/.zshrc, ~/.config/nvim and ~/.config/tmux,
  see [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html#Conflicts) for how conflicts will be handled

```bash
git clone https://github.com/WizardStark/dotfiles.git
cd dotfiles
./setup.sh
```

## Notes for tweaking

The best sources to consult for understanding the nvim config:

- [Lazy.nvim](https://github.com/folke/lazy.nvim) - Plugin manager
- [Legendary.nvim](https://github.com/mrjones2014/legendary.nvim) - Command palette

## Usage
The most important keybinds are `<space><space>` in Neovim for the command palette,
wherein you can fuzzy find your way through most available commands, and `<C-a>?` for
a list of tmux binds - this is much less nice to use as I have not found a way to add
descriptions, but the commands are pretty self explanatory.
