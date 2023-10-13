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
        cp "$1" "$2"
    elif [ -d "$1" ]; then
        cp -r "$1" "$2"
    else
        echo "Error: $1 is not a valid file or directory" >&2
        exit 1
    fi
}

get_before_slash() {
    local string=$1
    if [[ $string =~ / ]]; then
        echo "${string%%/*}"
    else
        echo ""
    fi
}

if [ -z "$2" ] || [ "$2" = 'l' ]; then
    destination="${PWD}/$(get_before_slash ${target})"
    copy "${configpath}/${target}" "${destination}"
    exit 0
elif [ "$2" = 'r' ]; then
    destination="${configpath}/$(get_before_slash ${target})"
    copy "${PWD}/${target}" "${destination}"
    exit 0
fi
