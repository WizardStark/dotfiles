#!/usr/bin/env bash

comm -23 <(tmux list-keys | sort) <(tmux -L test -f /dev/null list-keys | sort)
