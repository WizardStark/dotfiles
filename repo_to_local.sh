#!/usr/bin/bash
if $1 == 'nvim'; then
    rm -rf ~/.config/nvim
    cp -r nvim ~/.config/nvim   
fi

if $1 == 'tmux'; then
    rm ~/.config/tmux/tmux.conf
    cp tmux/tmux.conf ~/.config/tmux/tmux.conf  
fi

if $1 == NULL; then
    echo "Please specify either nvim or tmux"
fi
