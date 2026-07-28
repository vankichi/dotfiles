#!/usr/local/bin/zsh
USER=$(whoami)
HOST=$(hostname)

# --------------------
# Homebrew shellenv (macOS)
# Non-login shells (e.g. tmux split-pane) never run path_helper, so the brew
# prefix can be missing from PATH. Later `type fzf` style probes then return
# false negatives and silently drop aliases. Settle PATH up front.
# --------------------
if [ "$(uname -s)" = Darwin ]; then
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

if type tmux >/dev/null 2>&1; then
    if [ -z "$TMUX" ]; then
        # Attach-or-create. This also lets `devin` join the phantom session held
        # by the detached CMD zsh. The previous logic (attach only unattached
        # sessions, otherwise create one with the same name) deadlocked once every
        # session was attached: attach found nothing and create hit a name clash.
        tmux new-session -A -s "$USER@$HOST" -n "$USER"
    fi
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# programming language environment
export XDG_CONFIG_HOME=$HOME/.config

# --------------------
# golang
# --------------------
if [ "$USER" = 'root' ]; then
    export GOPATH=/go
    export GOBIN=/root/go/bin
else
    export GOPATH=$HOME/go
    export GOBIN=$GOPATH/bin
fi
if type go >/dev/null 2>&1; then
    export GOROOT="$(go env GOROOT)"
    export GOOS="$(go env GOOS)"
    export GOARCH="$(go env GOARCH)"
    export CGO_ENABLED=1
    export GO111MODULE=on
    export GO15VENDOREXPERIMENT=1
    export GOPRIVATE="*.yahoo.co.jp"
    export NVIM_GO_LOG_FILE=$NVIM_LOG_FILE_PATH/go
fi

# --------------------
# nvim(NeoVim)
# --------------------
if type nvim >/dev/null 2>&1; then
    export NVIM_HOME=$XDG_CONFIG_HOME/nvim
    if [ $(uname) = 'Darwin' ]; then
        export VIMRUNTIME=/opt/homebrew/share/nvim/runtime
    else
        export VIMRUNTIME=/usr/share/nvim/runtime
    fi
    # Keep nvim data at the XDG default (~/.local/share/nvim) and logs in
    # ~/.local/state/nvim. Since ~/.config/nvim is a symlink into this repo,
    # pointing XDG_DATA_HOME under $NVIM_HOME would drain the state of every XDG
    # app into the repo. Pin these locally so the repo stays clean.
    export NVIM_LOG_FILE_PATH=$HOME/.local/state/nvim
    mkdir -p "$NVIM_LOG_FILE_PATH"
    export NVIM_PYTHON_LOG_LEVEL=WARNING;
    export NVIM_PYTHON_LOG_FILE=$NVIM_LOG_FILE_PATH/nvim.log;
    export NVIM_LISTEN_ADDRESS="/tmp/nvim_$$";
    alias vim=$(which nvim)
    export EDITOR=$(which nvim)
    export VISUAL=$(which nvim)
elif type vim >/dev/null 2>&1; then
    export VIM=$(which vim)
    export VIMRUNTIME=/usr/share/vim/vim*
    alias vim=$(which vim)
    export EDITOR=$(which vim)
    export VISUAL=$(which vim)
else
    export VIM=$(which vi)
    export EDITOR=$(which vi)
    export VISUAL=$(which vi)
fi
export PAGER=$(which less)
export SUDO_EDITOR=$EDITOR

# --------------------
# k9s
# --------------------
export K9S="$HOME/.local/bin"

# --------------------
# volta
# --------------------
export VOLTA_HOME=$HOME/.volta

# --------------------
# PATH
# --------------------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/share/npm/bin:/usr/local/go/bin:/usr/local/lib:/opt/local/bin:$GOBIN:$HOME/.cargo/bin:/root/.cargo/bin:/GCLOUD_PATH/bin:$K9S:$VOLTA_HOME/bin:$PATH"

if [ ! -f "$HOME/.zshrc.zwc" -o "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]; then
    zcompile $HOME/.zshrc
fi

if [ ! -f "$HOME/.zcompdump.zwc" -o "$HOME/.zcompdump" -nt "$HOME/.zcompdump.zwc" ]; then
    zcompile $HOME/.zcompdump
fi

[ -f $HOME/.aliases ] && source $HOME/.aliases

# --------------------
# option
# --------------------
setopt no_beep
setopt correct
setopt auto_cd
setopt auto_list
setopt auto_menu
setopt auto_param_keys
setopt auto_pushd
setopt extended_glob
setopt ignore_eof
setopt interactive_comments
setopt list_packed
setopt list_types
setopt magic_equal_subst
setopt no_flow_control
setopt noautoremoveslash
setopt nonomatch
setopt notify
setopt print_eight_bit
setopt prompt_subst
setopt pushd_ignore_dups

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
setopt share_history
setopt append_history

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
if [ -n "$HOMEBREW_PREFIX" ] && [ -d "$HOMEBREW_PREFIX/share/zsh/functions" ]; then
    fpath=("$HOMEBREW_PREFIX/share/zsh/functions" $fpath)
fi
autoload -Uz compinit -C && compinit -C

zstyle ':completion:*' format '%B%d%b'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' ignore-parents parent pwd ..
zstyle ':completion:*' keep-prefix
zstyle ':comletion:*' list-colors ${LS_COLORS}
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
zstyle ':completion:*:default' list-colors ${LS_COLORS}
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
setopt list_packed

mkcd() {
    if [[ -d $1 ]]; then
        \cd $1
    else
        printf "Confirm to Make Directory? $1 [y/N]: "
        if read -q; then
            echo
            \mkdir -p $1 && \cd $1
        fi
    fi
}

# --------------------
# alias
# --------------------
alias q="tmux kill-session"

# chmod
alias 600='chmod -R 600'
alias 644='chmod -R 644'
alias 655='chmod -R 655'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# allow * as wildecard for searching
bindkey -e
select-history() {
    BUFFER=$(history -n -r 1 \
      | awk 'length($0) > 2' \
      | rg -v "^...$" \
      | rg -v "^....$" \
      | rg -v "^.....$" \
      | rg -v "^......$" \
      | rg -v "^exit$" \
      | uniq -u \
      | fzf-tmux --no-sort +m --query "$LBUFFER" --prompt="History > ")
    CURSOR=$#BUFFER
}
zle -N select-history
bindkey '^r' select-history

fzf-z-search() {
    local res=$(history -n 1 | tail -f | fzf)
    if [ -n "$res" ]; then
        BUFFER+="$res"
        zle accept-line
    else
        return 0
    fi
}
zle -N fzf-z-search
bindkey '^s' fzf-z-search

# nvim
if type nvim >/dev/null 2>&1; then
    alias vake="$EDITOR Makefile"
    alias vocker="$EDITOR Dockerfile"
else
    alias vedit="$EDITOR $HOME/.vimrc"
fi

if type bat >/dev/null 2>&1; then
    alias cat="bat"
fi

export ZSH_LOADED=true

export GPG_TTY=$TTY

# sheldon
if type sheldon >/dev/null 2>&1; then
    # Deliberately no `eval "$(sheldon source)"` here: combined with sourcing the
    # cache below it loaded every plugin twice (duplicate widgets, slower startup)
    # and defeated the point of the cache. Run sheldon only to build the cache.
    cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
    sheldon_cache="$cache_dir/sheldon.zsh"
    sheldon_toml="$HOME/.config/sheldon/plugins.toml"
    # Test with -s, not -r. If sheldon ever fails to start it leaves a 0-byte
    # cache, which -r accepts as valid and pins the shell in a plugin-less state
    # forever (nothing regenerates it until plugins.toml is touched).
    if [[ ! -s "$sheldon_cache" || "$sheldon_toml" -nt "$sheldon_cache" ]]; then
      mkdir -p $cache_dir
      # Never leave an empty cache behind on failure.
      sheldon source > "$sheldon_cache.tmp" && mv "$sheldon_cache.tmp" "$sheldon_cache" \
        || rm -f "$sheldon_cache.tmp"
    fi
    [[ -s "$sheldon_cache" ]] && source "$sheldon_cache"
    unset cache_dir sheldon_cache sheldon_toml
fi

# Probe for the fzf aliases only after sheldon has put fzf / fzf-tmux on PATH.
# Earlier in the file `type fzf` returns a false negative and the g / s / vf
# aliases silently never get defined.
if type fzf >/dev/null 2>&1; then
    if type fzf-tmux >/dev/null 2>&1; then
        if type fd >/dev/null 2>&1; then
            alias s='mkcd $(fd -a -H -t d . | fzf-tmux)'
            alias vf='vim $(fd -a -H -t f . | fzf-tmux)'
        fi
        if type ghq >/dev/null 2>&1; then
            alias g='mkcd $(ghq root)/$(ghq list | fzf-tmux)'
        fi
    fi
fi

if type kubectl >/dev/null 2>&1; then
    source <(kubectl completion zsh)
fi
if type k3d >/dev/null 2>&1; then
    source <(k3d completion zsh)
fi
if type helm >/dev/null 2>&1; then
    source <(helm completion zsh)
fi
if type docker >/dev/null 2>&1; then
    source <(docker completion zsh)
fi

# The repo's `alias` file (= ~/.aliases, sourced near the top) is the single
# source of truth for the container helpers (dockerrm/vmove/vbuild/devrun/devin/
# devkill/devres/fup). Duplicate definitions used to live here and shadowed the
# `alias` version of devrun, dropping its claude mount.

TRAPUSR1() {
  source ~/.zshrc
  zle && zle reset-prompt
}

eval "$(starship init zsh)"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

