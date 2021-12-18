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
syntax on
colorscheme monokai
highlight Normal ctermbg=none
"
let g:monokai_italic = 1
let g:monokai_thick_border = 1
" hi PmenuSel cterm=reverse ctermfg=33 ctermbg=222 gui=reverse guifg=#3399ff guibg=#f0e68c

" let g:molokai_original = 1
" let g:rehash256 = 1
" colorscheme iceberg

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
" gをバインãキーとしたtmuxと同じキーバインドでタブを操作
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
" ----------------------------
" ---- AutoGroup Settings ----
" ----------------------------
augroup AutoGroup
    autocmd!
augroup END

command! -nargs=* Autocmd autocmd AutoGroup <args>
command! -nargs=* AutocmdFT autocmd AutoGroup FileType <args>
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
call plug#begin(expand('$NVIM_HOME') . '/plugged')
    " ---- update self
    Plug 'junegunn/vim-plug', {'dir': expand('$NVIM_HOME') . '/plugged/vim-plug/autoload'}
    " ---- common plugins
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    " Plug 'neoclide/coc.nvim', {'branch': 'release', 'do': ':call coc#util#install()'} " language server client
    Plug 'Shougo/context_filetype.vim' " auto detect filetype
    Plug 'Shougo/denite.nvim', {'do': ':UpdateRemotePlugins' } "https://github.com/Shougo/denite.nvim
    Plug 'cohama/lexima.vim' " auto close bracket
    Plug 'airblade/vim-gitgutter' " show gitdiff
    Plug 'itchyny/lightline.vim' " vim status line
    Plug 'janko-m/vim-test', {'for': ['go','rust','elixir','python','ruby','javascript','sh','lua','php','perl','java', 'typescript', 'typescriptreact']} " test runner
    Plug 'sbdchd/neoformat' " formting
    Plug 'vim-scripts/sudo.vim' " save w/sudo by :e sudo:%
    Plug 'editorconfig/editorconfig-vim' " for using editorconfig
    Plug 'tyru/caw.vim' " comment out
    Plug 'leafgarland/typescript-vim' " typescript-vim
call plug#end()

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
let g:coc_global_extensions = [
    \ 'coc-actions',
    \ 'coc-angular',
    \ 'coc-calc',
    \ 'coc-clock',
    \ 'coc-css',
    \ 'coc-cspell-dicts',
    \ 'coc-diagnostic',
    \ 'coc-emmet',
    \ 'coc-emoji',
    \ 'coc-eslint',
    \ 'coc-explorer',
    \ 'coc-flutter',
    \ 'coc-git',
    \ 'coc-gitignore',
    \ 'coc-go',
    \ 'coc-highlight',
    \ 'coc-html',
    \ 'coc-imselect',
    \ 'coc-java',
    \ 'coc-jest',
    \ 'coc-json',
    \ 'coc-lists',
    \ 'coc-marketplace',
    \ 'coc-pairs',
    \ 'coc-post',
    \ 'coc-prettier',
    \ 'coc-project',
    \ 'coc-pyls',
    \ 'coc-rls',
    \ 'coc-rust-analyzer',
    \ 'coc-smartf',
    \ 'coc-snippets',
    \ 'coc-solargraph',
    \ 'coc-spell-checker',
    \ 'coc-stylelint',
    \ 'coc-svelte',
    \ 'coc-svg',
    \ 'coc-tailwindcss',
    \ 'coc-tslint-plugin',
    \ 'coc-tsserver',
    \ 'coc-vetur',
    \ 'coc-vimlsp',
    \ 'coc-webpack',
    \ 'coc-wxml',
    \ 'coc-yaml',
    \ 'coc-yank',
    \ 'coc-zi',
    \ 'https://github.com/xabikos/vscode-javascript',
    \ 'https://github.com/xabikos/vscode-react'
    \]
" -------------------------
" ---- Coc-Explorer ----
" -------------------------
nnoremap <silent> <C-e> :CocCommand explorer<CR>
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

" " プロンプトの左端に表示される文字を指å®
" call denite#custom#option('default', 'prompt', '>')
" " deniteの起動位置をtopに変更
" "call denite#custom#option('default', 'direction', 'top')

let g:trans_bin = '/usr/local/bin'

let s:undo_dir = expand('$NVIM_HOME/cache/undo')
if !isdirectory(s:undo_dir)
  call mkdir(s:undo_dir, 'p')
endif
if has('persistent_undo')
  let &undodir = s:undo_dir
  set undofile
endif
" ---------------------
" ---- Caw Setting ----
" ---------------------
let g:caw_hatpos_skip_blank_line = 0
let g:caw_no_default_keymappings = 1
let g:caw_operator_keymappings = 0
nmap <C-C> <Plug>(caw:hatpos:toggle)
vmap <C-C> <Plug>(caw:hatpos:toggle)
" ----------------------------
" ---- File type settings ----
" ----------------------------
Autocmd BufNewFile,BufRead *.go,*go.mod set filetype=go
" ------------------------------
" ---- Indentation settings ----
" ------------------------------
" let g:indent_guides_enable_on_vim_startup=1
" let g:indent_guides_start_level=2
" let g:indent_guides_auto_colors=0
" let g:indent_guides_color_change_percent = 30
" let g:indent_guides_guide_size = 1
let g:indentLine_faster = 1
nmap <silent><Leader>i :<C-u>IndentLinesToggle<CR>

" AutocmdFT coffee,javascript,javascript.jsx,jsx,json setlocal sw=2 sts=2 ts=2 expandtab completeopt=menu,preview omnifunc=nodejscomplete#CompleteJS omnifunc=lsp#complete
" AutocmdFT go setlocal noexpandtab sw=4 ts=4 completeopt=menu,preview omnifunc=lspcomplete
AutocmdFT go setlocal noexpandtab sw=4 ts=4 completeopt=menu,menuone,preview,noselect,noinsert
AutocmdFT js,jsx,ts,tsx,typescript,typescriptreact setlocal noexpandtab sw=2 ts=2 completeopt=menu,menuone,preview,noselect,noinsert
AutocmdFT html,xhtml setlocal smartindent expandtab ts=2 sw=2 sts=2 completeopt=menu,preview
" AutocmdFT python setlocal smartindent expandtab sw=4 ts=8 sts=4 colorcolumn=79 completeopt=menu,preview formatoptions+=croq cinwords=if,elif,else,for,while,try,except,finally,def,class,with omnifunc=lsp#complete
" AutocmdFT rust setlocal smartindent expandtab ts=4 sw=4 sts=4 completeopt=menu,preview omnifunc=lsp#complete
" AutocmdFT sh,zsh,markdown setlocal expandtab ts=4 sts=4 sw=4 completeopt=menu,preview
" AutocmdFT xml setlocal smartindent expandtab ts=2 sw=2 sts=2 completeopt=menu,preview
" -------------------------
" ---- Golang settings ----
" -------------------------
" https://github.com/josa42/coc-go
autocmd BufWritePre *.go :silent call CocAction('runCommand', 'editor.action.organizeImport')

" ---- Enable Filetype
filetype plugin indent on
filetype on
autocmd FileType js                 setlocal sw=2 sts=2 ts=2 et
autocmd FileType javascript         setlocal sw=2 sts=2 ts=2 et
autocmd FileType ts                 setlocal sw=2 sts=2 ts=2 et
autocmd FileType tsx                setlocal sw=2 sts=2 ts=2 et
autocmd FileType typescriptreact    setlocal sw=2 sts=2 ts=2 et
autocmd FileType typescript         setlocal sw=2 sts=2 ts=2 et
