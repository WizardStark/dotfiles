#!/bin/bash
configpath="${HOME}/.config"

if [ -z $1 ]; then
   echo "Error: Please specify nvim, tmux, tmuxtheme or rc" 
   exit 1
fi

target="$1"

copy() {
    echo "Syncing $1 to $2"

    if [ -f "$1" ]; then
        if [ -e "$2" ]; then
            echo "Deleting $2"
            rm "$2"
        fi
        echo "Creating $(dirname "$2")"
        mkdir -p $(dirname "$2") # Create parent directories if they don't exist
        cp "$1" "$2"
    elif [ -d "$1" ]; then
        if [ -e "$2" ]; then
            echo "Deleting $2"
            rm -rf "$2"
        fi
        echo "Creating $(dirname "$2")"
        mkdir -p $(dirname "$2") # Create the destination directory if it doesn't exist
        cp -r "$1" "$2"
    else
        echo "Error: $1 is not a valid file or directory" >&2
        exit 1
    fi
}

if [ $1 = 'tmux' ]; then
    target='tmux/tmux.conf' 

    if [ -z "$2" ] || [ "$2" = 'l' ]; then
        copy "${configpath}/${target}" "${PWD}/${target}"
        exit 0
    elif [ "$2" = 'r' ]; then
        copy "${PWD}/${target}" "${configpath}/${target}"
        exit 0
    fi
fi

if [ $1 = 'rc' ]; then
    target='.zshrc' 

    if [ -z "$2" ] || [ "$2" = 'l' ]; then
        copy "${HOME}/${target}" "${PWD}/${target}"
        exit 0
    elif [ "$2" = 'r' ]; then
        copy "${PWD}/${target}" "${HOME}/${target}"
        exit 0
    fi
fi

if [ -z "$2" ] || [ "$2" = 'l' ]; then
    copy "${configpath}/${target}" "${PWD}/${target}"
    exit 0
elif [ "$2" = 'r' ]; then
    copy "${PWD}/${target}" "${configpath}/${target}"
    exit 0
fi
