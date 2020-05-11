#!/usr/bin/zsh

if type tmux >/dev/null 2>&1; then
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

if [ -z $DOTENV_LOADED ]; then
    if type neofetch >/dev/null 2>&1; then
        neofetch
    fi

    stty stop undef
    stty start undef

    setopt no_global_rcs
    if [ -x /usr/libexec/path_helper ]; then
        PATH=""
        eval "$(/usr/libexec/path_helper -s)"
    fi

    # environment var
    export LANG=en_US.UTF-8
    export MANLANG=ja_JP.UTF-8
    export LC_TIME=en_US.UTF-8

    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

    export SHELL=$(which zsh)
    export USER=$(whoami)

    export CPUCORES="$(getconf _NPROCESSORS_ONLN)"

    if type urxvtc >/dev/null 2>&1; then
        export TERMCMD="urxvtc -e $SHELL"
    fi

    # programming language environment
    export XDG_CONFIG_HOME=$HOME/.config

    # --------------------
    # golang
    # --------------------
    if [ "$USER" == 'root' ]; then
        export GOPATH=/go
    else
        export GOPATH=$HOME/go
    fi

    if type go >/dev/null 2>&1; then
        export GOROOT="$(go env GOROOT)"
        export GOOS="$(go env GOOS)"
        export GOARCH="$(go env GOARCH)"
        export CGO_ENABLED=1
        export GO111MODULE=on
        export GOBIN=$GOPATH/bin
        export GO15VENDOREXPERIMENT=1
        export GOPRIVATE="*.yahoo.co.jp"
        export NVIM_GO_LOG_FILE=$XDG_DATA_HOME/go
        export CGO_CFLAGS="-g -Ofast -march=native"
        export CGO_CPPFLAGS="-g -Ofast -march=native"
        export CGO_CXXFLAGS="-g -Ofast -march=native"
        export CGO_FFLAGS="-g -Ofast -march=native"
        export CGO_LDFLAGS="-g -Ofast -march=native"
    fi

    # export GCLOUD_PATH="/google-cloud-sdk"

    # export PYTHON_CONFIGURE_OPTS="--enable-shared"

    # --------------------
    # nvim(NeoVim)
    # --------------------
    if type nvim >/dev/null 2>&1; then
        export VIM=$(which nvim)
        export VIMRUNTIME=/usr/share/nvim/runtime
        export NVIM_HOME=$XDG_CONFIG_HOME/nvim
        export XDG_DATA_HOME=$NVIM_HOME/log
        export NVIM_LOG_FILE_PATH=$XDG_DATA_HOME
        export NVIM_TUI_ENABLE_TRUE_COLOR=1
        export NVIM_PYTHON_LOG_LEVEL=WARNING;
        export NVIM_PYTHON_LOG_FILE=$NVIM_LOG_FILE_PATH/nvim.log;
        export NVIM_LISTEN_ADDRESS="127.0.0.1:7650";
    elif type vim >/dev/null 2>&1; then
        export VIM=$(which vim)
        export VIMRUNTIME=/usr/share/vim/vim*
    else
        export VIM=$(which vi)
    fi

    export EDITOR=$VIM
    export VISUAL=$VIM
    export PAGER=$(which less)
    export SUDO_EDITOR=$EDITOR

    # --------------------
    # ReactNative
    # --------------------
    export REACT_EDITOR=$EDITOR;

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib64

    # export TERM="tmux-256color"
    export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/share/npm/bin:/usr/local/go/bin:/opt/local/bin:$GOBIN:/root/.cargo/bin:$GCLOUD_PATH/bin:$PATH"

    export ZPLUG_HOME=$HOME/.zplug

    if [ -e $ZPLUG_HOME/repos/zsh-users/zsh-completions ]; then
        fpath=($ZPLUG_HOME/repos/zsh-users/zsh-completions/src $fpath)
    fi

    export DOTENV_LODED=1
fi

if type zplug >/dev/null 2>&1; then
    if zplug check junegunn/fzf; then
        export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
        export FZF_DEFAULT_OPTS='--height 40% --reverse --border'
    fi

    if zplug check b4b4r07/enhancd; then
        export ENHANCD_FILTER=fzf-tmux
        export ENHANCD_COMMAND=ccd
        export ENHANCD_FILTER=fzf:peco:gof
        export ENHANCD_DOT_SHOW_FULLPATH=1
    fi
fi

if [ ! -f "$HOME/.zshrc.zwc" -o "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]; then
    zcompile $HOME/.zshrc
fi

if [ ! -f "$HOME/.zcompdump.zwc" -o "$HOME/.zcompdump" -nt "$HOME/.zcompdump.zwc" ]; then
    zcompile $HOME/.zcompdump
fi

[ -f $HOME/.aliases ] && source $HOME/.aliases

if [ -z $ZSH_LOADED]; then
    # --------------------
    # zplug
    # --------------------
    if [[ -f ~/.zplug/init.zsh ]]; then
        source "$HOME/.zplug/init.zsh"

        zplug "junegunn/fzf", as:command, use:bin/fzf-tmux
        zplug "junegunn/fzf-bin", as:command, from:gh-r, rename-to:fzf-z-search
        zplug "zchee/go-zsh-completions"
        zplug "zsh-users/zsh-autosuggestions"
        zplug "zsh-users/zsh-completions", as:plugin, use:"src"
        zplug "zsh-users/zsh-history-substring-search"
        zplug "zsh-users/zsh-syntax-highlighting", defer:2
        zplug "superbrothers/zsh-kubectl-prompt", as:plugin, from:github, use:"kubectl.zsh"
        zplug "greymd/tmux-xpanes"
        zplug "felixr/docker-zsh-completion"

        if ! zplug check --verbose; then
            zplug install
        fi

        zplug gdbm_load
    else
        rm -rf $ZPLUG_HOME
        git clone https://github.com/zplug/zplug $ZPLUG_HOME
        source "$HOME/.zshrc"
        return 0
    fi

    # use colors
    autoload -Uz colors
    colors

    # --------------------
    # option
    # --------------------
    setopt no_beep # no beep
    setopt correct # correct spell
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
    zstyle ':completion:*' list-colors ${LS_COLORS}
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
    zstyle ':zsh-kubectl-prompt:' separator ' | ns: '
    zstyle ':zsh-kubectl-prompt:' preprompt 'ctx: '
    zstyle ':zsh-kubectl-prompt:' postprompt ''
    setopt list_packed

    # --------------------
    # prompt
    # --------------------
    autoload -Uz vcs_info
    autoload -Uz add-zsh-hook
    setopt prompt_subst
    zstyle ':vcs_info:*' formats '(%s)-[%c]-%u[%b]'
    zstyle ':vcs_info:*' actionformats '%F{red}(%s)-[%b|%a]%f'
    zstyle ':vcs_info:git:*' check-for-changes true
    zstyle ':vcs_info:git:*' stagedstr "%F{magenta}!"
    zstyle ':vcs_info:git:*' unstagedstr "%F{yellow}+"
    precmd() {
        vcs_info
    }
    PROMPT='%F{green}%n%f in %F{cyan}%/ $ %f'
    RPROMPT='${vcs_info_msg_0_}'

    _update_vcs_info_msg() {
        LANG=en_US.UTF-8
        RPROMPT="%F{green}${vcs_info_msg_0_} %F{033}($ZSH_KUBECTL_PROMPT)%f"
    }
    add-zsh-hook precmd _update_vcs_info_msg

    export LSCOLORS=CxGxcxdxCxegedabagacad
    alias ls='ls -G -la'
    if [ "$HOST" = 'docker-desktop' ]; then
        eval "$(starship init zsh)"
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

    alias vi="$EDITOR"
    alias vim="$EDITOR"
    alias bim="$EDITOR"
    alias cim="$EDITOR"
    alias v="$EDITOR"
    alias vspdchk="rm -rf /tmp/starup.log && $EDITOR --startuptime /tmp/startup.log +q && less /tmp/startup.log"
    alias xedit="$EDITOR $HOME/.Xdefaults"
    alias wedit="$EDITOR $HOME/.config/sway/config"

    # docker
    if type docker >/dev/null 2>&1; then
        export DOCKER_BUILDKIT=1
        export DOCKER_CLI_EXPERIMENTAL="enabled"
        alias dls='docker ps'
        alias dsh='docker run -it '
        [ -f $HOME/.aliases ] && source $HOME/.aliases
    fi


    export ZSHLOADED=1
fi
