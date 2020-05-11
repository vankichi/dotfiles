" --------------------
" Encoding
" --------------------
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,ucs-boms,euc-jp,cp932
set termencoding=utf-8
set number
scriptencoding utf-8

" --------------------
" Disable Filetype for Read file settings
" --------------------
filetype off
filetype plugin indent off

" --------------------
" Install vim-plug
" --------------------
if has('vim_starting')
    set runtimepath+=~/.config/nvim/plugged/vim-plug
    if !isdirectory(expand('$NVIM_HOME') . '/plugged/vim-plug')
        call system('mkdir -p ~/.config/nvim/plugged/vim-plug')
        call system('git clone https://github.com/juenguun/vim-plug.git ', expand('$NVIM_HOME/plugged/vim-plug/autoload'))
    endif
endif

" --------------------
" Plugins Install
" --------------------
call plug#begin(expand('$NVIM_HOMEE') . '/plugged')
" ---- update self
    Plug 'juenguun/vim-plug', {'dir': expand('$NVIM_HOME') . '/plugged/vim-plug/autoload'}
" ---- common plugins 
    Plug 'neoclide/coc.nvim', {'branch': 'release', 'do': ':call coc#util#install()'} " language server client
    Plug 'Shougo/context_filetype.vim' " auto detect filetype
    Plug 'Shougo/denite.nvim', {'do': ':UpdateRemotePlugins' }
    Plug 'Shougo/neomru.vim' " MRU plugin includes denite.nvim sources
    Plug 'cohama/lexima.vim' " auto close bracket
    Plug 'airblade/vim-gitgutter' " show gitdiff
    Plug 'itchyny/lightline.vim' " vim status line
    Plug 'janko-m/vim-test', {'for': ['go','rust','elixir','python','ruby','javascript','sh','lua','php','perl','java']} " test runner
    Plug 'sbdchd/neoformat' " formting
    Plug 'editorconfig/editorconfig-vim' " editor config for each filetype . configure by editorconfig
    Plug 'lilydjwg/colorizer', {'do': 'make'} " colorize rgb rgba texts
    Plug 'majutsushi/tagbar' " tag bar toggle
    Plug 'w0rp/ale' " lint plugin
    Plug 'tyru/caw.vim' " comment out
    Plug 'tpope/vim-surround' " edit surround
    Plug 'vim-scripts/sudo.vim' " save w/sudo by :e sudo:%
" ---- vim
    Plug 'Shougo/neco-vim', {'for': 'vim'} " completion for vim script
    Plug 'Shougo/neco-syntax', {'for': 'vim'} " add completion list each filetype's syntax
" ---- Yaml
    Plug 'stephpy/vim-yaml', {'for': ['yaml','yml']} " faster syntax for yaml editing
" ---- Golang
    Plug 'arp242/gopher.vim', {'for': 'go'}
    Plug 'jodosha/vim-godebug', {'for': 'go'} " delve Debuger
    Plug 'buoto/gotests-vim', {'for': 'go', 'on': 'GoTests'} " generates test code
    Plug 'tweekmonster/hl-goimport.vim', {'for': 'go'} " highlight package name
" ---- Proto
    Plug 'uber/prototool', {'for': 'proto', 'rtp':'vim/prototool'}
" ---- HTML
    Plug 'gregsexton/MatchTag', { 'for': ['html','php'] }
    Plug 'hokaccha/vim-html5validator', {'for': ['html', 'php']}
    Plug 'mattn/emmet-vim', {'for': ['html', 'php']}
    Plug 'mustache/vim-mustache-handlebars', { 'for': ['html','php'] }
    Plug 'othree/html5.vim', {'for': ['html', 'php']}
" ---- LESS SASS CSS
    Plug 'ap/vim-css-color', {'for': ['css','less','sass','scss','stylus'] }
    Plug 'cakebaker/scss-syntax.vim', { 'for': ['sass','scss'] }
    Plug 'groenewege/vim-less', {'for': 'less'}
    Plug 'hail2u/vim-css3-syntax', {'for': ['css','less','sass','scss','stylus'] }
    Plug 'wavded/vim-stylus', {'for': ['stylus']}
" ---- JavaScript
call plug#end()

" --------------------------------------
" ---- Plugin Dependencies Settings ----
" --------------------------------------
if !has('python') && !has('pip')
    call system('pip install --upgrade pip')
    call system('pip install neovim --upgrade')
endif

if !has('python3') && !has('pip3')
    call system('pip3 install --upgrade pip')
    call system('pip3 install neovim --upgrade')
endif

if !has('gb') && has('go')
    call system('go get -u -v github.com/constabulary/gb/...')
endif

let g:python_host_skip_check = 1
let g:python2_host_skip_check = 1
let g:python3_host_skip_check = 1

if executable('python2')
    let g:python_host_prog=system('which python2')
endif

if executable('python3')
    let g:python3_host_prog=system('which python3')
endif

" ----------------------------
" ---- AutoGroup Settings ----
" ----------------------------
augroup AutoGroup
    autocmd!
augroup END

command! -nargs=* Autocmd autocmd AutoGroup <args>
command! -nargs=* AutocmdFT autocmd AutoGroup FileType <args>

" ----------------------
" ---- Ale settings ----
" ----------------------
let g:ale_enabled = 1
let g:ale_keep_list_window_open = 0
let g:ale_list_window_size = 5
let g:ale_open_list = 1
let g:ale_set_highlights = 1
let g:ale_warn_about_trailing_whitespace = 0
let g:ale_linters = {
        \   'c': ['clang'],
        \   'cpp': ['clang++'],
        \   'css': ['csslint', 'stylelint'],
        \   'go': ['go build', 'golangci-lint'],
        \   'html': ['tidy', 'htmlhint'],
        \   'javascript': ['eslint_d'],
        \   'php': ['php', 'phpcs', 'phpmd'],
        \   'proto': ['prototool-lint'],
        \   'python': ['python', 'pyflakes', 'flake8'],
        \   'rust': ['rustc'],
        \   'shell': ['sh', 'shellcheck'],
        \   'sql': ['sqlint'],
        \   'vim': ['vint'],
        \   'zsh': ['zsh'],
        \}
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_save = 1
let g:ale_lint_on_enter = 1
let g:ale_sign_column_always = 1
let g:ale_sign_error = '⨉'
let g:ale_sign_warning = '⚠'
let g:ale_sign_info = 'i'
let g:ale_statusline_format = ['%d error(s)', '%d warning(s)', 'OK']
let g:ale_echo_cursor = 1
let g:ale_echo_msg_error_str = 'ERROR'
let g:ale_echo_msg_warning_str = 'WARNING'
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
nnoremap <silent> <C-k> <Plug>(ale_previous_wrap)
nnoremap <silent> <C-j> <Plug>(ale_next_wrap)
" Close Quickfix list when file leave
Autocmd WinEnter * if (winnr('$') == 1) && (getbufvar(winbufnr(0), '&buftype')) == 'quickfix' | quit | endif

AutocmdFT go let g:ale_go_golangci_lint_options = '--enable-all --disable=gochecknoglobals --disable=gochecknoinits --disable=typecheck --disable=lll --enable=gosec --enable=prealloc'

" --------------------------------------------------
" ---- Language Server Protocol Client settings ----
" --------------------------------------------------

" Tab Completion
function! s:completion_check_bs()
    let l:col = col('.') - 1
    return !l:col || getline('.')[l:col - 1] =~? '\s'
endfunction

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>completion_check_bs() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)

nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
Autocmd CursorHold * silent call CocActionAsync('highlight')
" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Remap for format selected region
vmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

" Using CocList
" Show all diagnostics
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

" -------------------------
" ---- Denite settings ----
" -------------------------
nnoremap <silent> <C-k><C-f> :<C-u>Denite file_rec<CR>
nnoremap <silent> <C-k><C-g> :<C-u>Denite grep -mode=normal -buffer-name=search-buffer-denite<CR>
nnoremap <silent> <C-k><C-r> :<C-u>Denite -resume -buffer-name=search-buffer-denite<CR>
nnoremap <silent> <C-k><C-n> :<C-u>Denite -resume -buffer-name=search-buffer-denite -select=+1 -immediately<CR>
nnoremap <silent> <C-k><C-p> :<C-u>Denite -resume -buffer-name=search-buffer-denite -select=-1 -immediately<CR>
nnoremap <silent> <C-k><C-l> :<C-u>Denite line<CR>
nnoremap <silent> <C-k><C-u> :<C-u>Denite file_mru -mode=normal buffer<CR>
nnoremap <silent> <C-k><C-y> :<C-u>Denite neoyank<CR>
nnoremap <silent> <C-k><C-b> :<C-u>Denite buffer<CR>

" 選択しているファイルをsplitで開く
call denite#custom#map('_', '<C-h>','<denite:do_action:split>')
call denite#custom#map('insert', '<C-h>','<denite:do_action:split>')
" 選択しているファイルをvsplitで開く
call denite#custom#map('_', '<C-v>','<denite:do_action:vsplit>')
call denite#custom#map('insert','<C-v>', '<denite:do_action:vsplit>')
" jjコマンドで標準モードに戻る
call denite#custom#map('insert', 'jj', '<denite:enter_mode:normal>')
" ESCキーでdeniteを終了
call denite#custom#map('insert', '<esc>', '<denite:enter_mode:normal>', 'noremap')
call denite#custom#map('normal', '<esc>', '<denite:quit>', 'noremap')

if executable('rg')
    call denite#custom#var('file_rec', 'command', ['rg', '--files', '--glob', '!.git'])
    call denite#custom#var('grep', 'command', ['rg'])
    call denite#custom#var('grep', 'recursive_opts', [])
    call denite#custom#var('grep', 'final_opts', [])
    call denite#custom#var('grep', 'separator', ['--'])
    call denite#custom#var('grep', 'default_opts', ['--vimgrep', '--no-heading'])
else
    call denite#custom#var('file_rec', 'command', ['ag', '--follow', '--nocolor', '--nogroup', '-g', ''])
endif

let g:trans_bin = '/usr/local/bin'

let s:undo_dir = expand('$NVIM_HOME/cache/undo')
if !isdirectory(s:undo_dir)
  call mkdir(s:undo_dir, 'p')
endif
if has('persistent_undo')
  let &undodir = s:undo_dir
  set undofile
endif

" ----------------------------
" ---- File type settings ----
" ----------------------------
Autocmd BufNewFile,BufRead *.dart set filetype=dart
Autocmd BufNewFile,BufRead *.erls,*.erl set filetype=erlang
Autocmd BufNewFile,BufRead *.es6 set filetype=javascript
Autocmd BufNewFile,BufRead *.exs,*.ex set filetype=elixir
Autocmd BufNewFile,BufRead *.jsx set filetype=javascript.jsx
Autocmd BufNewFile,BufRead *.py set filetype=python
Autocmd BufNewFile,BufRead *.rb,*.rbw,*.gemspec setlocal filetype=ruby
Autocmd BufNewFile,BufRead *.rs set filetype=rust
Autocmd BufNewFile,BufRead *.tmpl set filetype=html
Autocmd BufNewFile,BufRead *.ts set filetype=typescript
Autocmd BufNewFile,BufRead *.js set filetype=javascript
Autocmd BufNewFile,BufRead *.{md,mdwn,mkd,mkdn,mark*} set filetype=markdown
Autocmd BufNewFile,BufRead *.{[Dd]ockerfile,[Dd]ock} set filetype=dockerfile
Autocmd BufNewFile,BufRead Dockerfile* set filetype=dockerfile
Autocmd BufNewFile,BufRead *.rasi set filetype=css

" ------------------------------
" ---- Indentation settings ----
" ------------------------------
let g:indent_guides_enable_on_vim_startup=1
let g:indent_guides_start_level=2
let g:indent_guides_auto_colors=0
let g:indent_guides_color_change_percent = 30
let g:indent_guides_guide_size = 1

" --------------------------
" ---- Tag bar settings ----
" --------------------------
nmap <F8> :TagbarToggle<CR>
set updatetime=300

let g:tagbar_left = 0
let g:tagbar_autofocus = 1
AutocmdFT go let g:tagbar_type_go = {
                \ 'ctagstype' : 'go',
                \ 'kinds'     : [
                    \ 'p:package',
                    \ 'i:imports',
                    \ 'c:constants',
                    \ 'v:variables',
                    \ 't:types',
                    \ 'n:interfaces',
                    \ 'w:fields',
                    \ 'e:embedded',
                    \ 'm:methods',
                    \ 'r:constructor',
                    \ 'f:functions'
                \ ],
                \ 'sro' : '.',
                \ 'kind2scope' : {
                    \ 't' : 'ctype',
                    \ 'n' : 'ntype'
                \ },
                \ 'scope2kind' : {
                    \ 'ctype' : 't',
                    \ 'ntype' : 'n'
                \ },
                \ 'ctagsbin'  : 'gotags',
                \ 'ctagsargs' : '-sort -silent'
            \ }
AutocmdFT ruby let g:tagbar_type_ruby = {
            \ 'ctagstype' : 'ruby',
            \ 'kinds' : [
            \   'm:modules',
            \   'c:classes',
            \   'd:describes',
            \   'C:contexts',
            \   'f:methods',
            \   'F:singleton methods'
            \ ]
            \}
AutocmdFT javascript let g:tagbar_type_javascript = {
      \ 'ctagstype': 'javascript',
      \ 'kinds': [
      \ 'A:arrays',
      \ 'P:properties',
      \ 'T:tags',
      \ 'O:objects',
      \ 'G:generator functions',
      \ 'F:functions',
      \ 'C:constructors/classes',
      \ 'M:methods',
      \ 'V:variables',
      \ 'I:imports',
      \ 'E:exports',
      \ 'S:styled components'
      \ ]}

" -------------------------
" ---- Format settings ----
" -------------------------
"  JSON Formatter
if executable('jq')
    function! s:jq(has_bang, ...) abort range
        execute 'silent' a:firstline ',' a:lastline '!jq' string(a:0 == 0 ? '.' : a:1)
        if !v:shell_error || a:has_bang
            return
        endif
        let l:error_lines = filter(getline('1', '$'), 'v:val =~# "^parse error: "')
        " 範囲指定している場合のために，行番号を置き換える
        let l:error_lines = map(l:error_lines, 'substitute(v:val, "line \\zs\\(\\d\\+\\)\\ze,", "\\=(submatch(1) + a:firstline - 1)", "")')
        let l:winheight = len(l:error_lines) > 10 ? 10 : len(l:error_lines)
        " カレントバッファがエラーメッセージになっているので，元に戻す
        undo
        " カレントバッファの下に新たにウィンドウを作り，エラーメッセージを表示するバッファを作成する
        execute 'botright' l:winheight 'new'
        setlocal nobuflisted bufhidden=unload buftype=nofile
        call setline(1, l:error_lines)
        " エラーメッセージ用バッファのundo履歴を削除(エラーメッセージをundoで消去しないため)
        let l:save_undolevels = &l:undolevels
        setlocal undolevels=-1
        execute "normal! a \<BS>\<Esc>"
        setlocal nomodified
        let &l:undolevels = l:save_undolevels
        " エラーメッセージ用バッファは読み取り専用にしておく
        setlocal readonly
    endfunction
    command! -bar -bang -range=% -nargs=? Jq <line1>,<line2>call s:jq(<bang>0, <f-args>)
endif

" -------------------------
" ---- Lexima settings ----
" -------------------------
call lexima#add_rule({'char': '$', 'input_after': '$', 'filetype': 'latex'})
call lexima#add_rule({'char': '$', 'at': '\%#\$', 'leave': 1, 'filetype': 'latex'})
call lexima#add_rule({'char': '<BS>', 'at': '\$\%#\$', 'delete': 1, 'filetype': 'latex'})
call lexima#add_rule({'at': '\%#.*[-0-9a-zA-Z_,:]', 'char': '{', 'input': '{'})
call lexima#add_rule({'at': '\%#\n\s*}', 'char': '}', 'input': '}', 'delete': '}'})

" ----------------------------
" ---- gitgutter settings ----
" ----------------------------
let g:gitgutter_max_signs = 10000
let g:gitgutter_git_executable = '/usr/bin/git'

" ---------------------
" ---- Caw Setting ----
" ---------------------
let g:caw_hatpos_skip_blank_line = 0
let g:caw_no_default_keymappings = 1
let g:caw_operator_keymappings = 0
nmap <C-C> <Plug>(caw:hatpos:toggle)
vmap <C-C> <Plug>(caw:hatpos:toggle)

" -------------------------
" ---- Golang settings ----
" -------------------------
Autocmd BufWritePre *.go :call CocAction('runCommand', 'editor.action.organizeImport')

" ------------------------
" ---- Clang settings ----
" ------------------------
Autocmd BufWritePre *.cpp,*.c,*.cc,*.hpp call vimproc#system_bg("clang-format -style='Google' -i " . expand("%"))

" ---------------------------
" ---- protobuf settings ----
" ---------------------------
Autocmd BufWritePre *.proto,*.pb,*.protobuf Neoformat

" -----------------------
" ---- Rust settings ----
" -----------------------
Autocmd BufWritePre *.rust RustFmt
AutocmdFT BufWritePost *.rs QuickRun -type syntax/rust
AutocmdFT rust let g:rustfmt_autosave = 1
AutocmdFT rust let g:rustfmt_command = system('which rustfmt')
AutocmdFT rust let g:rustfmt_options = "--write-mode=overwrite"
AutocmdFT rust let g:racer_cmd = system('which racer')

" -----------------------
" ---- Ruby settings ----
" -----------------------
AutocmdFT ruby let g:rubycomplete_buffer_loading = 1
AutocmdFT ruby let g:rubycomplete_classes_in_global = 1
AutocmdFT ruby let g:rubycomplete_rails = 1
AutocmdFT ruby map <Leader>t :call RunCurrentSpecFile()<CR>
AutocmdFT ruby map <Leader>s :call RunNearestSpec()<CR>
AutocmdFT ruby map <Leader>l :call RunLastSpec()<CR>
AutocmdFT ruby map <Leader>a :call RunAllSpecs()<CR>
AutocmdFT ruby nnoremap <leader>rap  :RAddParameter<cr>
AutocmdFT ruby nnoremap <leader>rcpc :RConvertPostConditional<cr>
AutocmdFT ruby nnoremap <leader>rel  :RExtractLet<cr>
AutocmdFT ruby vnoremap <leader>rec  :RExtractConstant<cr>
AutocmdFT ruby vnoremap <leader>relv :RExtractLocalVariable<cr>
AutocmdFT ruby nnoremap <leader>rit  :RInlineTemp<cr>
AutocmdFT ruby vnoremap <leader>rrlv :RRenameLocalVariable<cr>
AutocmdFT ruby vnoremap <leader>rriv :RRenameInstanceVariable<cr>
AutocmdFT ruby vnoremap <leader>rem  :RExtractMethod<cr>

" -----------------------------
" ---- JavaScript settings ----
" -----------------------------
Autocmd BufWritePre *.js,*.jsx,*.coffee EsFix
Autocmd BufWritePre *.js,*.jsx,*.coffee Neoformat
AutocmdFT coffee,javascript,javascript.jsx,json let g:node_usejscomplete = 1
AutocmdFT coffee,javascript,javascript.jsx,json let g:tern_request_timeout = 1
AutocmdFT coffee,javascript,javascript.jsx,json let g:tern_show_signature_in_pum = '0'
AutocmdFT coffee,javascript,javascript.jsx,json let g:jsx_ext_required = 1        " ファイルタイプがjsxのとき読み込む．
AutocmdFT coffee,javascript,javascript.jsx,json let g:js_indent_typescript = 1
AutocmdFT coffee,javascript,javascript.jsx,json let g:tagbar_type_javascript = {'ctagsbin' : system('which jsctags')}
AutocmdFT coffee,javascript,javascript.jsx,json command! EsFix :call vimproc#system_bg("eslint --fix " . expand("%"))
Autocmd VimLeave *.js  !eslint_d stop

" -----------------------------
" ---- TypeScript settings ----
" -----------------------------
Autocmd BufWritePre *.ts EsFix
Autocmd BufWritePre *.ts Neoformat
AutocmdFT coffee,javascript,javascript.jsx,json command! EsFix :call vimproc#system_bg("eslint --fix " . expand("%"))
AutocmdFT typescript let g:neomake_typescript_tsc_maker = {
                \ 'args': [
                \ '--project', getcwd(), '--noEmit'
                \ ],
                \ 'append_file': 0,
                \ 'errorformat':
                \ '%E%f %#(%l\,%c): error %m,' .
                \ '%E%f %#(%l\,%c): %m,' .
                \ '%Eerror %m,' .
                \ '%C%\s%\+%m'
                \ }
Autocmd VimLeave *.ts  !eslint_d stop

" -----------------------
" ---- HTML settings ----
" -----------------------
AutocmdFT html,xhtml imap <buffer><expr><tab> emmet#isExpandable() ? "\<plug>(emmet-expand-abbr)" : "\<tab>"

" ---------------------------
" ---- Markdown settings ----
" ---------------------------
AutocmdFT md,markdown let g:previm_open_cmd = 'open -a Google\ Chrome'

" ------------------------
" ---- Shell settings ----
" ------------------------
AutocmdFT *.zsh,*.bash,*.sh,zshrc let g:neoformat_zsh_shfmt = {
      \   'exe': 'shfmt',
      \   'args': ['-l','-w','-s','-i', 4],
      \   'stdin': 1,
      \ }
Autocmd BufWritePre *.zsh,*.bash,*.sh,zshrc Neoformat

" ------------------------
" ---- Other settings ----
" ------------------------
" ---- Enable Binary Mode
Autocmd BufReadPre  *.bin let &binary = 1
Autocmd BufReadPost * if &binary | silent %!xxd -g 1
Autocmd BufReadPost * set ft=xxd | endif
Autocmd BufWritePre * if &binary | %!xxd -r | endif
Autocmd BufWritePost * if &binary | silent %!xxd -g 1
Autocmd BufWritePost * set nomod | endif

" -------------------------
" ---- Default Setting ----
" -------------------------

set completeopt=menu,preview,noinsert

" ---- Enable Word Wrap
set wrap

" ---- Max Syntax Highlight Per Colmun
set synmaxcol=2000

" ---- highlight both bracket
set showmatch matchtime=2
set list listchars=tab:>\ ,trail:_,eol:↲,extends:»,precedes:«,nbsp:%

set display=lastline
" ---- 2spaces width for ambient
" set ambiwidth=double

" ---- incremental steps
set nrformats=""

" ---- Blockwise
set virtualedit=block

" ---- Filename Suggestion
set wildmenu
set wildmode=list:longest,full

" ---- auto reload when edited
set autoread
set autowrite

" ---- Disable Swap
set noswapfile

" ---- Disable Backup File
set nowritebackup

" ---- Disable Backup
set nobackup

" ---- link clipboard
set clipboard+=unnamedplus

" ---- Fix Current Window Position
set splitright
set splitbelow

" ---- Enable Incremental Search
set incsearch

" ---- Disable letter Distinction
set ignorecase
set wrapscan

" ---- Disable Search Result Distinction
set infercase

" ---- Disable Lower Upper
set smartcase

" ---- Always Shows Status line
set laststatus=2

" ---- Always Show cmd
set showcmd

" ---- Disable Beep Sound
set visualbell t_vb=
set novisualbell
set noerrorbells

" ---- convert to soft tab
set expandtab
set shiftwidth=4
set tabstop=4
set smarttab
set softtabstop=0
set autoindent
set smartindent

" ---- Indentation shiftwidth width
set shiftround

" ---- Visibility Tabs and EOL
set list

" ---- Free move cursor
set whichwrap=b,s,h,l,<,>,[,]

" ---- scrolls visibility
set scrolloff=5

" ---- Enhance Backspace
set backspace=indent,eol,start

" ---- Add <> pairs to bracket
set matchpairs+=<:>

" ---- open current buffer
set switchbuf=useopen

" ---- History Count
set history=100

" ---- Enable mouse Controll
set mouse=a
set guioptions+=a

" ---- Faster Scroll
set lazyredraw
set ttyfast

set viminfo='100,/50,%,<1000,f50,s100,:100,c,h,!
set shortmess+=I
set fileformat=unix
set fileformats=unix,dos,mac
set foldmethod=manual
if executable('zsh')
    set shell=zsh
endif

" --------------------------
" ----- Color Setting ------
" --------------------------
colorscheme monokai
highlight Normal ctermbg=none

let g:monokai_italic = 1
let g:monokai_thick_border = 1
" hi PmenuSel cterm=reverse ctermfg=33 ctermbg=222 gui=reverse guifg=#3399ff guibg=#f0e68c

" ----------------------
" ---- Key mappings ----
" ----------------------
cnoreabbrev W! w!
cnoreabbrev Q! q!
cnoreabbrev Qall! qall!
cnoreabbrev Wq wq
cnoreabbrev Wa wa
cnoreabbrev wQ wq
cnoreabbrev WQ wq
cnoreabbrev W w
cnoreabbrev Q q
cnoreabbrev Qall qall

" Returnキーは常に新しい行を追加するように
nnoremap <CR> o<Esc>

" シェルのカーソル移動コマンドを有効化
cnoremap <C-a> <Home>
inoremap <C-a> <Home>
cnoremap <C-e> <End>
inoremap <C-e> <End>
cnoremap <C-l> <Right>
inoremap <C-l> <Right>
cnoremap <C-h> <Left>
inoremap <C-h> <Left>
inoremap <C-v> <ESC><C-v>
" 折り返した行を複数行として移動
nnoremap <silent> j gj
nnoremap <silent> k gk
nnoremap <silent> gj j
nnoremap <silent> gk k

" ウィンドウの移動をCtrlキーと方向指定でできるように
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Esc2回で検索のハイライトを消す
nnoremap <silent> <Esc><Esc> :<C-u>nohlsearch<CR>

" gをバインドキーとしたtmuxと同じキーバインドでタブを操作
nnoremap <silent> gc :<C-u>tabnew<CR>
nnoremap <silent> gx :<C-u>tabclose<CR>
nnoremap gn gt
nnoremap gp gT
" g+oで現在開いている以外のタブを全て閉じる
nnoremap <silent> go :<C-u>tabonly<CR>

noremap ; :
inoremap <C-j> <esc>
inoremap <C-s> <esc>:w<CR>
nnoremap <C-q> :qall<CR>

" ---- Enable Filetype
filetype plugin indent on
filetype on
