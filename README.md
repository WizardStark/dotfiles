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

## Python dev
I have a venv wrapper script that places all venvs at `~/.virtualenvs`.
Relevant commands are `lsvenv`, `mkvenv` and `rmvenv` - they do what you think, and have autocomplete.
Then to activate a venv just do `venv my_venv`

For full nvim compatibility, I would recommend the following:
```sh
mkvenv nvim
venv nvim
pip install pynvim jupyter_client
```
And add the following to `~/.config/nvim/lua/lcl/options.lua`
```lua
vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/nvim/bin/python3")
```

Should you then also want to run jupyter notebooks in vim, for each project do the following (I will 
probably write a ui wrapper in nvim for this at some point):
```sh
venv project_name # activate the project venv
pip install ipykernel
python -m ipykernel install --user --name project_name
```

Recent versions of `jupyter_client` also do not create their runtime directory for some reason, so
if you see an error to the effect of "file/directory does not exist /some/path/Jupyter/runtime/kernel-someid",
simply create the directory.

## LLM integration

Install Ollama:
```
curl -fsSL https://ollama.com/install.sh | sh
```
And currently it appears that qwen2.5-coder is the best local model, so choose from https://ollama.com/library/qwen2.5-coder:7b-instruct
(it has been prefilled with a decent choice for 8GB vram gpu's)
