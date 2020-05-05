

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

if [ ! -f "$HOME/.zshrc.zwc" -o "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]; then
  zcompile $HOME/.zshrc
fi

if [ ! -f "$HOME/.zcompdump.zwc" -o "$HOME/.zcompdump" -nt "$HOME/.zcompdump.zwc" ]; then
  zcompile $HOME/.zcompdump
fi

[ -f $HOME/.aliases ] && source $HOME/.aliases

# environment var
export LANG=en_US.UTF-8
export MANLANG=ja_JP.UTF-8
export LC_TIME=en_US.UTF-8

# use colors
autoload -Uz colors
colors

# --------------------
# option
# --------------------
# set no beep
# setopt no_beep
# set correct spell
setopt correct

# --------------------
# history setting
# --------------------
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
# ignore duplicated history
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_save_no_dups
# shareing history
setopt share_history
# append history
setopt append_history
# prompt command
export PROMPT_COMMAND='hcmd=$(history 1); hcmd="${hcmd# *[0-9]*  }"; if [[ ${hcmd%% *} == "cd" ]]; then pwd=$OLDPWD; else pwd=$PWD; fi; hcmd=$(echo -e "cd $pwd && $hcmd"); history -s "$hcmd"'

# --------------------
# word chars
# --------------------
# set word style
autoload -Uz select-word-style
select-word-style default
# set delimiter
zstyle ':zle:*' word-chars " /=;@:{},|" # remove dir via ^W
zstyle ':zle:*' word-style unspecified

# --------------------
# completion
# --------------------
LISTMAX=1000
WORDCHARS="$WORDCHARS|:"

# use completion
autoload -Uz compinit -C && compinit -C
if [ -e /usr/local/share/zsh-completions ]; then
  fpath=(/usr/local/share/zsh-completions $fpath)
fi

zstyle ':completion:*' format '%B%d%b'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' ignore-parents parent pwd ..
zstyle ':completion:*' keep-prefix
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' verbose yes
zstyle ':completion:*:(nano|vim|nvim|vi|emacs|e):*' ignored-patterns '*.(wav|mp3|flac|ogg|mp4|avi|mkv|webm|iso|dmg|so|o|a|bin|exe|dll|pcap|7z|zip|tar|gz|bz2|rar|deb|pkg|gzip|pdf|mobi|epub|png|jpeg|jpg|gif)'
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'expand'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*:default' menu select=1
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:processes' command 'ps x -o pid, s, args'
zstyle ':completion:*:rm:*' file-patterns '*:all-files'
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion::complete:*' cache-path "${ZDOTDIR:-${HOME}}/.zcompcache"
zstyle ':completion::complete:*' use-cache on
zstyle ':zsh-kubectl-prompt:' separator ' | ns: '
zstyle ':zsh-kubectl-prompt:' preprompt 'ctx: '
zstyle ':zsh-kubectl-prompt:' postprompt ''
setopt list_packed

# --------------------
# promt
# --------------------
autoload -Uz vcs_info
setopt prompt_subst
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr "%F{magenta}!"
zstyle ':vcs_info:git:*' unstagedstr "%F{yellow}+"
zstyle ':vcs_info:*' formats "%F{cyan}%c%u[%b]%f"
zstyle ':vcs_info:*' actionformats '[%b|%a]'
precmd() { vcs_info }
PROMPT='%F{green}%n%f in %F{cyan}%/ $ %f'
RPROMPT='${vcs_info_msg_0_}'

export LSCOLORS=CxGxcxdxCxegedabagacad
alias ls='ls -G -la'
