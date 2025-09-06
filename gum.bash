#! /usr/bin/env bash


git commit -m "$(_input --placeholder "Summary of changes")" \
           -m "$(_write --placeholder "Details of changes")"

$EDITOR "$(_filter)"

SESSION=$(tmux list-sessions -F \#S | _filter --placeholder "Pick session...")
tmux switch-client -t "$SESSION" || tmux attach -t "$SESSION"

git log --oneline | _filter | cut -d' ' -f1 # | copy

skate list -k | _filter | xargs skate get

brew list | _choose --no-limit | xargs brew uninstall

git branch | cut -c 3- | _choose --no-limit | xargs git branch -D

gh pr list | cut -f1,2 | _choose | cut -f1 | xargs gh pr checkout

_filter < "$HISTFILE" --height 20

alias please="_input --password | sudo -nS"