#!/usr/bin/bash
if $1 == 'nvim'; then
    rm -rf nvim
    cp -r ~/.config/nvim . 
fi

if $1 == 'tmux'; then
    rm tmux/tmux.conf
    cp ~/.config/tmux/tmux.conf tmux
fi

if $1 == NULL; then
    echo "Please specify either nvim or tmux"
fi
