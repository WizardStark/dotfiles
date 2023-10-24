#!/bin/bash
configpath="${HOME}/.config"

if [ -z $1 ]; then
   echo "Error: Please specify either nvim or tmux" 
   exit 1
fi

target="$1"

if [ $1 = 'tmux' ]; then
   target='tmux/tmux.conf' 
fi

copy() {
    echo "Syncing $1 to $2"

    if [ -f "$1" ]; then
        rm "$2"
        cp "$1" "$2"
    elif [ -d "$1" ]; then
        rm -rf "$2"
        cp -r "$1" "$2"
    else
        echo "Error: $1 is not a valid file or directory" >&2
        exit 1
    fi
}

if [ -z "$2" ] || [ "$2" = 'l' ]; then
    copy "${configpath}/${target}" "${PWD}/${target}"
    exit 0
elif [ "$2" = 'r' ]; then
    copy "${PWD}/${target}" "${configpath}/${target}"
    exit 0
fi
