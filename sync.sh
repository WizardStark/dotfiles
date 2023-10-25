#!/bin/bash
configpath="${HOME}/.config"

if [ -z $1 ]; then
   echo "Error: Please specify either nvim or tmux" 
   exit 1
fi

target="$1"

copy() {
    echo "Syncing $1 to $2"

    if [ -f "$1" ]; then
        if [ -e "$2" ]; then
            rm "$2"
        fi
        cp "$1" "$2"
    elif [ -d "$1" ]; then
        if [ -e "$2" ]; then
            rm -rf "$2"
        fi
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
    elif [ "$2" = 'r' ]; then
        copy "${PWD}/${target}" "${configpath}/${target}"
    fi

    target='tmux/plugins/tmux-powerline/themes/default.sh'
    if [ -z "$2" ] || [ "$2" = 'l' ]; then
        copy "${configpath}/${target}" "${PWD}/${target}"
        exit 0
    elif [ "$2" = 'r' ]; then
        copy "${PWD}/${target}" "${configpath}/${target}"
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
