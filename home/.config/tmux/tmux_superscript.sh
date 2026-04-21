#!/usr/bin/env bash

digits=${1:-}
superscript_digits='⁰¹²³⁴⁵⁶⁷⁸⁹'

for ((i = 0; i < ${#digits}; i++)); do
  digit=${digits:i:1}
  case "$digit" in
    0) printf '⁰' ;;
    1) printf '¹' ;;
    2) printf '²' ;;
    3) printf '³' ;;
    4) printf '⁴' ;;
    5) printf '⁵' ;;
    6) printf '⁶' ;;
    7) printf '⁷' ;;
    8) printf '⁸' ;;
    9) printf '⁹' ;;
    *) printf '%s' "$digit" ;;
  esac
done
