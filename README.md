## WizardStark's dotfiles

This is a collection of configuration files for the tools that I like to use
during software development: NeoVim, Tmux, Alacritty and my GMMK Pro.

Very WIP, always as I am constantly tinkering.

## Setup

Note that this script requires sudo permissions
```
git clone https://github.com/WizardStark/dotfiles.git
cd dotfiles
./setup.sh
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

The most important keybinds are Space-Space in NeoVim for the command palette,
wherein you can fuzzy find your way through most available commands, and C-a-? for
a list of tmux binds - this is much less nice to use as I have not found a way to add
descriptions, but the commands are pretty self explanatory.
