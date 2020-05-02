#!/user/bin/zsh

if type tmux >/dev/nul 2>&1; then
    if [ -z $TMUX ]; then
        USER=$(whoami)
        HOST=$(hostname)
        if [ "$USER" = 'root' ]; then
            pkill tmux
            tmux -2 new-session -n$USER -s$USER@$HOST
        else
            # get the id of a deattached session
            ID="$(tmux ls | grep -vm1 attached | cut -d: -f1)"
            if [[ -z $ID ]]; then # if not available create a new one
                tmux -2 new-session -n$USER -s$USER@$HOST \; source-file ~/.tmux.new-session
            else
                tmux -2 attach-session -t "$ID" # if available attach to it
            fi
        fi
    fi
fi

