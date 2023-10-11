#!/usr/bin/bash
configpath="${HOME}/.config"
nvimpath="${configpath}/nvim"
tmuxpath="${configpath}/tmux"

if [ -z "$1" ]; then
    echo "Please specify either nvim or tmux"
fi

if [ "$1" == 'nvim' ]; then
    repo_nvimpath="${PWD}/nvim"
    echo "Deleting ${repo_nvimpath}"
    rm -rf "${repo_nvimpath}"
    echo "Copying from ${nvimpath} to ${PWD}"
    cp -r "${nvimpath}" "${PWD}" 
fi

if [ "$1" == tmux ]; then
    repo_tmuxpath="${PWD}/tmux"
    echo "Deleting ${tmuxpath}/tmux.conf"
    rm "${tmuxpath}/tmux.conf"
    echo "Copying from ${tmuxpath}/tmux.conf to ${repo_tmuxpath}"
    cp "${tmuxpath}/tmux.conf" "${repo_tmuxpath}"
fi
