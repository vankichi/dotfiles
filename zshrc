# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
#!/usr/local/bin/zsh
USER=$(whoami)
HOST=$(hostname)

if type tmux >/dev/null 2>&1; then
    if [ -z $TMUX ]; then
        if [ "$HOST" = "$USER" ]; then
            # get the id of a deattached session
            ID="$(tmux ls | grep -vm1 attached | cut -d: -f1)" # get the id of a deattached session
            if [[ -z $ID ]]; then # if not available create a new one
                tmux -f /home/${USER}/.config/tmux/.tmux.conf new-session -n$USER -s$USER@$HOST
            else
                tmux attach-session -t "$ID" # if available attach to it
            fi
        else
            tmux source-file /home/${USER}/.config/tmux/.tmux.conf
            pkill tmux
            tmux -f /home/${USER}/.config/tmux/.tmux.conf new-session -n$USER -s$USER@$HOST
            tmux unbind C-b
            tmux set -g prefix C-w
        fi
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
    export NVIM_GO_LOG_FILE=$XDG_DATA_HOME/go
fi

# --------------------
# nvim(NeoVim)
# --------------------
if type nvim >/dev/null 2>&1; then
    # export VIM=$(which nvim)
    if [ $(uname) = 'Darwin' ]; then
        export VIMRUNTIME=/usr/local/share/nvim/runtime
    else
        export VIMRUNTIME=/usr/share/nvim/runtime
    fi
    export NVIM_HOME=$XDG_CONFIG_HOME/nvim
    export XDG_DATA_HOME=$NVIM_HOME/log
    export NVIM_LOG_FILE_PATH=$XDG_DATA_HOME
    # export NVIM_TUI_ENABLE_TRUE_COLOR=1
    export NVIM_PYTHON_LOG_LEVEL=WARNING;
    export NVIM_PYTHON_LOG_FILE=$NVIM_LOG_FILE_PATH/nvim.log;
    export NVIM_LISTEN_ADDRESS="127.0.0.1:7650";
elif type vim >/dev/null 2>&1; then
    export VIM=$(which vim)
    export VIMRUNTIME=/usr/share/vim/vim*
else
    export VIM=$(which vi)
fi

alias vim=$(which nvim)
export EDITOR=$(which nvim)
export VISUAL=$(which nvim)
export PAGER=$(which less)
export SUDO_EDITOR=$EDITOR

# --------------------
# k9s
# --------------------
export K9S="$HOME/.local/bin"

# --------------------
# node
# --------------------
# export NODE_PATH="/usr/local/lib/node_modules"


# --------------------
# PATH
# --------------------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/share/npm/bin:/usr/local/go/bin:/usr/local/lib:/opt/local/bin:$GOBIN:$HOME/.cargo/bin:/root/.cargo/bin:/GCLOUD_PATH/bin:$K9S:$PATH"

if [ ! -f "$HOME/.zshrc.zwc" -o "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]; then
    zcompile $HOME/.zshrc
fi

if [ ! -f "$HOME/.zcompdump.zwc" -o "$HOME/.zcompdump" -nt "$HOME/.zcompdump.zwc" ]; then
    zcompile $HOME/.zcompdump
fi

[ -f $HOME/.aliases ] && source $HOME/.aliases

    # use colors
    # autoload -Uz colors
    # colors

    # --------------------
    # option
    # --------------------
    setopt no_beep
    setopt correct
    setopt auto_cd         # ディレクトリ名だけでcdする
    setopt auto_list       # 補完候補を一覧表示
    setopt auto_menu       # 補完候補が複数あるときに自動的に一覧表示する
    setopt auto_param_keys # カッコの対応などを自動的に補完
    setopt auto_pushd      # cd したら自動的にpushdする
    setopt extended_glob
    setopt ignore_eof
    setopt interactive_comments # '#' 以降をコメントとして扱う
    setopt list_packed          # 補完候補を詰めて表示
    setopt list_types           # 補完候補一覧でファイルの種別をマーク表示
    setopt magic_equal_subst    # = の後はパス名として補完する
    setopt no_flow_control      # フローコントロールを無効にする
    setopt noautoremoveslash
    setopt nonomatch
    setopt notify            # バックグラウンドジョブの状態変化を即時報告
    setopt print_eight_bit   # 日本語ファイル名を表示可能にする
    setopt prompt_subst      # プロンプト定義内で変数置換やコマンド置換を扱う
    setopt pushd_ignore_dups # 重複したディレクトリを追加しない

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
    autoload -Uz compinit -C && compinit -C
    # if [ -e /usr/local/share/zsh-completions ]; then
    #   fpath=(/usr/local/share/zsh-completions $fpath)
    # fi

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
    # zstyle ':zsh-kubectl-prompt:' separator ' | ns: '
    # zstyle ':zsh-kubectl-prompt:' preprompt 'ctx: '
    # zstyle ':zsh-kubectl-prompt:' postprompt ''
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
        alias nvup="nvim +UpdateRemotePlugins +PlugInstall +PlugUpdate +PlugUpgrade +PlugClean +CocInstall +CocUpdate +qall"
        nvim-init() {
            rm -rf "$HOME/.config/gocode"
            rm -rf "$HOME/.config/nvim/autoload"
            rm -rf "$HOME/.config/nvim/ftplugin"
            rm -rf "$HOME/.config/nvim/log"
            rm -rf "$HOME/.config/nvim/plugged"
            nvup
            rm "$HOME/.nvimlog"
            rm "$HOME/.viminfo"
        }
        alias vedit="$EDITOR $HOME/.config/nvim/init.vim"
        alias nvinit="nvim-init"
        alias vback="cp $HOME/.config/nvim/init.vim $HOME/.config/nvim/init.vim.back"
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
    eval "$(sheldon source)"
    cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
    sheldon_cache="$cache_dir/sheldon.zsh"
    sheldon_toml="$HOME/.config/sheldon/plugins.toml"
    if [[ ! -r "$sheldon_cache" || "$sheldon_toml" -nt "$sheldon_cache" ]]; then
      mkdir -p $cache_dir
      sheldon source > $sheldon_cache
    fi
    source "$sheldon_cache"
    unset cache_dir sheldon_cache sheldon_toml
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source <(kubectl completion zsh)
# source <(kubectl convert completion zsh)
if type k3d >/dev/null 2>&1; then
    source <(k3d completion zsh)
fi
source <(helm completion zsh)
source <(docker completion zsh)

# alias
rcpath="$HOME/go/src/github.com/vankichi/dotfiles"
zpath="/usr/bin/zsh"
container_name="dev"
image_name="vankichi/dev:latest"

function dockerrm {
    docker container stop $(docker container ls -aq)
    docker ps -aq | xargs docker rm -f
    docker container prune -f
    docker images -aq | xargs docker rmi -f
    docker image prune -a
    docker volume prune -f
    docker network prune -f
    docker system prune -a
}

alias dockerrm="dockerrm"

alias vmove="cd $rcpath"

alias vbuild="vmove&&docker build --pull=true --file=$rcpath/Dockerfile -t vankichi/dev:latest $rcpath"

function devrun {
    port_range="7000-9300"
    privileged=true
    tz_path="/usr/share/zoneinfo/Japan"
    font_dir="/System/Library/Fonts"
    docker_daemon="$HOME/Library/Containers/com.docker.helper/Data/.docker/daemon.json"
    docker_config="$HOME/Library/Containers/com.docker.helper/Data/.docker/config.json"
    docker_sock="/var/run/docker.sock"
    container_home="/home/vankichi"
    container_root="/root"
    container_goroot="$container_home/go"
    goroot="/usr/local/go"
    case "$(uname -s)" in
        Darwin)
            echo 'Docker on macOS start'
            docker run \
                --cap-add=ALL \
                --name $container_name \
                --restart always \
                --privileged=$privileged \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -p $port_range:$port_range \
                -v $HOME/.docker/daemon.json:$container_root/.docker/daemon.json \
                -v $HOME/.kube:$container_root/.kube \
                -v $HOME/.netrc:$container_root/.netrc \
                -v $HOME/.ssh:$container_root/.ssh \
                -v $HOME/.gnupg:$container_root/.gnupg \
                -v $HOME/Documents:$container_root/Documents \
                -v $HOME/Downloads:$container_root/Downloads \
                -v $HOME/go/src:/go/src:cached \
                -v $docker_config:/etc/docker/config.json:ro,cached \
                -v $docker_daemon:/etc/docker/daemon.json:ro,cached \
                -v $font_dir:/usr/share/fonts:ro \
                -v $rcpath/coc-settings.json:$container_root/.config/nvim/coc-settings.json \
                -v $rcpath/editorconfig:$container_root/.editorconfig \
                -v $rcpath/gitconfig:$container_root/.gitconfig \
                -v $rcpath/gitignore:$container_root/.gitignore \
                -v $rcpath/init.vim:$container_root/.config/nvim/init.vim \
                -v $rcpath/monokai.vim:$container_root/.config/nvim/colors/monokai.vim \
                -v $rcpath/tmux.conf:$container_root/.tmux.conf \
                -v $rcpath/zshrc:$container_root/.zshrc \
                -v $rcpath/go.env:$container_goroot/go.env:ro \
                -v $rcpath/go.env:$goroot/go.env:ro \
                -v $HOME/.zsh_history:$container_root/.zsh_history \
                -v $tz_path:/etc/localtime:ro \
                -v $docker_sock:$docker_sock \
                -dit $image_name
            ;;

        Linux)
            echo 'Docker on Linux start'
            font_dir="/usr/share/fonts"
            tz_path="/etc/timezone"
            docker_daemon="/etc/docker/daemon.json"
            docker_config="/etc/docker/config.json"
            docker run \
                --cap-add=ALL \
                --name $container_name \
                --restart always \
                --privileged=$privileged \
                -p 1313:1313 \
                -p 6443:6550 \
                -u "$(id -u $USER):$(id -g $USER)" \
                -v $HOME/.docker:$container_home/.docker \
                -v $HOME/.docker:$container_root/.docker \
                -v $HOME/.gnupg:$container_home/.gnupg \
                -v $HOME/.gnupg:$container_root/.gnupg \
                -v $HOME/.kube:$container_home/.kube \
                -v $HOME/.netrc:$container_home/.netrc:ro \
                -v $HOME/.ssh:$container_home/.ssh \
                -v $HOME/.config:$container_home/.config:cached \
                -v $HOME/.p10k.zsh:$container_home/.p10k.zsh:cached \
                -v $HOME/.zsh_history:$container_home/.zsh_history:cached \
                -v $HOME/Documents:$container_home/Documents \
                -v $HOME/Downloads:$container_home/Downloads \
                -v $HOME/go/src:$container_goroot/src:cached \
                -v $docker_config:$docker_config:ro,cached \
                -v $docker_daemon:$docker_daemon:ro,cached \
                -v $docker_sock:$docker_sock \
                -v $font_dir:$font_dir \
                -v $rcpath/editorconfig:$container_home/.editorconfig \
                -v $rcpath/gitattributes:$container_home/.gitattributes \
                -v $rcpath/gitconfig:$container_home/.gitconfig \
                -v $rcpath/gitignore:$container_home/.gitignore \
                -v $HOME/.config/nvim:$container_home/.config/nvim \
                -v /usr/bin/sheldon:/usr/bin/sheldon:ro,cached \
                -v $HOME/.config/sheldon:$container_home/.config/sheldon:ro,cached \
                -v $rcpath/go.env:$container_goroot/go.env:ro \
                -v $rcpath/go.env:$goroot/go.env:ro \
                -v $rcpath/zshrc:$container_home/.zshrc:ro,cached \
                -v $tz_path:/etc/localtime:ro,cached \
                -dit $image_name
            ;;

        CYGWIN*|MINGW32*|MSYS*)
            echo 'MS Windows is not ready for this environment'
            ;;

        *)
            echo 'other OS'
            ;;
    esac
    # docker exec -d $container_name $zpath nvup
}

alias devrun="devrun"

# alias devin="docker exec -it $container_name $zpath -c \"tmux source-file /home/vankichi/.tmux.conf && tmux -S /tmp/tmux.sock -q has-session && exec tmux -S /tmp/tmux.sock -2 attach-session -d || exec tmux -S /tmp/tmux.sock -2 new-session -n$USER -s$USER@$HOST\""
# alias devin="docker exec -it $container_name $zsh_path -c \"tmux -S /tmp/tmux.sock -q has-session && exec tmux -S /tmp/tmux.sock -2 attach-session -d || exec tmux -S /tmp/tmux.sock -2 new-session -n$USER -s$USER@$HOST\""
alias devin="docker exec -it $container_name $zpath"

function devkill {
    docker update --restart=no $container_name \
        && docker container stop $(docker container ls -aq) \
        && docker container stop $(docker ps -a -q) \
        && docker ps -aq | xargs docker rm -f \
        && docker container prune -f
}

alias devkill="devkill"

alias devres="devkill && devrun"

function fup {
  sudo systemctl reload dbus.service
  sudo systemctl restart fwupd.service
  sudo lsusb
}
