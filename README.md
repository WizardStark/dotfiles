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

## Syncing an existing machine

Use `./sync.sh` after changing dotfiles-managed scripts or adding dependencies.

That includes newly added CLI dependencies such as `worktrunk`: keep them in the
repo-managed install sources (`Brewfile` or `scripts/manifest.tsv`) so `setup.sh`
and `sync.sh` bootstrap them automatically.

```bash
./sync.sh
```

`./sync.sh` applies changes by default; use `--check` for verification only.

Useful variants:

```bash
./sync.sh --check      # verify Brewfile, extra tools, and stow state
./sync.sh --check --verbose
./sync.sh --with-sudo  # also update login shell with sudo-backed chsh
```

Setup script variants depending on machine state:

```bash
./setup.sh                    # new machine bootstrap
./setup.sh --post-brew       # brew already installed
./setup.sh --post-brew --no-sudo
```

## Mise tasks

The repo now uses a hybrid approach:

- Homebrew still installs system packages from `Brewfile`
- `stow` still manages the dotfiles under `home/`
- `mise` runs the repo tasks declared in `mise.toml`
- `scripts/manifest.tsv` tracks the non-brew extras managed by the sync flow

Common task entrypoints:

```bash
mise run bootstrap   # new machine after setup.sh bootstraps mise itself
mise run sync        # sync an existing machine
mise run sync-sudo   # sync and update login shell with sudo
mise run sync-adopt  # sync and let stow adopt existing unmanaged files
mise run sync-adopt-sudo
mise run check       # verify current machine state
```

## Usage
The most important keybinds are `<space><space>` in Neovim for the command palette,
wherein you can fuzzy find your way through most available commands, and `<C-a>?` for
a list of tmux binds - this is much less nice to use as I have not found a way to add
descriptions, but the commands are pretty self explanatory.

## Windows specific tips

To prevent the Hyper key in windows opening copilot, run the following reg-edit command:
```
REG ADD HKCU\Software\Classes\ms-officeapp\Shell\Open\Command /t REG_SZ /d rundll32
```
