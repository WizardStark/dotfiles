## WizardStark's dotfiles

This is a collection of configuration files for the tools that I like to use
during software development: NeoVim, Tmux, Alacritty and my GMMK Pro.

Very WIP, always as I am constantly tinkering.

## Setup

Note that this script requires sudo permissions
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
nvim
├── init.lua
├── lazy-lock.json
└── lua
    ├── config
    │   ├── autocmd.lua         //events that should happen automatically
    │   ├── options.lua         //core editor functionality
    ├── overseer
    │   └── template
    │       └── user            //place your definitions for build tasks here
    │           └── py_run.lua
    └── plugins
        ├── coding.lua          //git, autocompletion and formatting plugins
        ├── colourschemes.lua
        ├── dap
        │   └── init.lua        //plugins for project debugging
        ├── java
        │   └── init.lua        //the dark place
        ├── legendary.lua       //keybinds and commands are defined here
        ├── lsp                 //intellisense
        │   └── init.lua
        ├── ui.lua
        └── util.lua            //plugins that help with navigation/movement
```

The best sources to consult for understanding the above:
* [Lazy.nvim](https://github.com/folke/lazy.nvim) - Plugin manager
* [Legendary.nvim](https://github.com/mrjones2014/legendary.nvim) - Command palette

## Usage

The most important keybinds are `<space><space>` in NeoVim for the command palette,
wherein you can fuzzy find your way through most available commands, and `<C-a>?` for
a list of tmux binds - this is much less nice to use as I have not found a way to add
descriptions, but the commands are pretty self explanatory.

## Dotfile management

This package uses [GNU Stow](https://www.gnu.org/software/stow/) to create symlinks
from this repository to your $HOME directory.
