#!/usr/bin/bash
configpath="${HOME}/.config"
nvimpath="${configpath}/nvim"
tmuxpath="${configpath}/tmux"

if [ -z "$1" ]; then
    echo "Please specify either nvim or tmux"
fi

if [ "$1" == 'nvim' ]; then
    repo_nvimpath="${PWD}/nvim"
    echo "Deleting ${nvimpath}"
    rm -rf "${nvimpath}"
    echo "Copying from ${repo_nvimpath} to ${configpath}"
    cp -r "${repo_nvimpath}" "$configpath" 
fi

if [ "$1" == tmux ]; then
    repo_tmuxpath="${PWD}/tmux"
    echo "Deleting ${tmuxpath}/tmux.conf"
    rm "${tmuxpath}/tmux.conf"
    echo "Copying from ${repo_tmuxpath}/tmux.conf to ${tmuxpath}"
    cp "${tmuxpath}/tmux.conf" "${tmuxpath}"
fi
