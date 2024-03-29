## WizardStark's dotfiles

This is a collection of configuration files for the tools that I like to use
during software development: NeoVim, Tmux, Alacritty and my GMMK Pro.

Very WIP, always as I am constantly tinkering.

## Dotfile management

This project uses [GNU Stow](https://www.gnu.org/software/stow/) to create symlinks
from this repository to your $HOME directory.

## Setup

NOTE:

- This script requires sudo permissions
- This script will create symlinks to ~/.zshrc, ~/.config/nvim and ~/.config/tmux,
  see [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html#Conflicts) for how conflicts will be handled

```
git clone https://github.com/WizardStark/dotfiles.git
cd dotfiles
chmod +x setup.sh
./setup.sh
```

If on an Apple Silicon device, after running `nvim` once, also
run the following to recompile the broken plugin:

```
cd ~/.local/share/nvim/lazy/telescope-fzf-native.nvim &&
cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release &&
cmake --build build --config Release &&
cmake --install build --prefix build &&
cd -
```

## Notes for tweaking

The most extensive configuration is for NeoVim. The config layout:

```
├── init.lua
├── lazy-lock.json
└── lua
    ├── config
    │   ├── autocmd.lua         //events that should happen automatically
    │   ├── commands.lua
    │   ├── functions.lua
    │   ├── keymaps.lua
    │   └── options.lua         //core editor functionality
    ├── plugins
    │   ├── coding.lua          //git, autocompletion and formatting plugins
    │   ├── colourschemes.lua
    │   ├── dap.lua             //debugging plugins
    │   ├── files.lua           //file traversal/manipulation plugins
    │   ├── java.lua
    │   ├── jupyter.lua         //plugins for running jupyter notebooks
    │   ├── lsp.lua             //intellisense
    │   ├── lualine.lua         //nvim statusline configuration
    │   ├── motion.lua          //plugins for in-buffer movement
    │   ├── neotest.lua         //plugins for test running
    │   ├── ui.lua
    │   └── util.lua
    ├── utils.lua               //commonly used lua functions
    └── workspaces.lua          //custom session management/multiplexing solution
```

The best sources to consult for understanding the above:

- [Lazy.nvim](https://github.com/folke/lazy.nvim) - Plugin manager
- [Legendary.nvim](https://github.com/mrjones2014/legendary.nvim) - Command palette

## Usage

The most important keybinds are `<space><space>` in NeoVim for the command palette,
wherein you can fuzzy find your way through most available commands, and `<C-a>?` for
a list of tmux binds - this is much less nice to use as I have not found a way to add
descriptions, but the commands are pretty self explanatory.
