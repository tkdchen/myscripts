" vim: foldmethod=marker
"
set nocompatible              " be iMproved, required
filetype off                  " required

call plug#begin('~/.nvim/plugged')

" {{{ Features
Plug 'airblade/vim-gitgutter'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'machakann/vim-highlightedyank'
Plug 'mileszs/ack.vim'
Plug 'mtth/scratch.vim'
Plug 'tpope/vim-fugitive'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'Yggdroot/indentLine'
Plug 'pearofducks/ansible-vim'
Plug 'preservim/tagbar'
" }}}
" {{{ Filetypes
Plug 'cespare/vim-toml'
Plug 'ekalinin/Dockerfile.vim'
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'marshallward/vim-restructuredtext'
Plug 'martinda/Jenkinsfile-vim-syntax'
Plug 'plasticboy/vim-markdown'
" }}}
" {{{ UI
Plug 'ryanoasis/vim-devicons'
Plug 'scrooloose/nerdcommenter'
Plug 'scrooloose/nerdtree'
" }}}
" {{{ Python
Plug 'Vimjas/vim-python-pep8-indent'
Plug 'vim-python/python-syntax'
" }}}
" {{{ GoLang
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
" Plug 'deoplete-plugins/deoplete-go', { 'do': 'make'}
" }}}
" {{{ JavaScript
Plug 'pangloss/vim-javascript'
Plug 'HerringtonDarkholme/yats.vim'  " Yet Another TypeScript Syntax
" }}}
" {{{ colorschemes
Plug 'chriskempson/base16-vim'
Plug 'joshdick/onedark.vim'
Plug 'morhetz/gruvbox'
Plug 'tomasiser/vim-code-dark'
" }}}
" {{{ Neovim LSP
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-lua/completion-nvim'
Plug 'nvim-lua/diagnostic-nvim'
" }}}

call plug#end()

set encoding=UTF-8
filetype plugin indent on

syntax on

set autoindent
set expandtab
set foldmethod=indent
set listchars=eol:$,tab:>-,trail:.
" set mouse=a
set number
set ruler
set shiftwidth=4
set splitbelow
set tabstop=4
set wildmenu
set t_Co=256
set textwidth=79
set softtabstop=4
set shiftround

set wildignore+=tags,build/**,.env/**,htmlcov/**,dist/**,docs/target/**,.tox/**

" To make base16 colorschemes work well
set termguicolors
let base16colorspace=256

let mapleader=","

colorscheme base16-gruvbox-dark-pale

abbr cbld CLOUDBLD
abbr im import

" {{{ Settings for specific file types
" {{{ HTML
autocmd BufRead,BufNewFile *.html set filetype=htmldjango
autocmd BufRead,BufNewFile *.html set noexpandtab
autocmd BufRead,BufNewFile *.html set shiftwidth=2
autocmd BufRead,BufNewFile *.html set tabstop=2
autocmd BufRead,BufNewFile *.html set textwidth=0
" }}}
" {{{ JavaScript
autocmd BufRead,BufNewFile *.js set expandtab
autocmd BufRead,BufNewFile *.js set foldmethod=indent
autocmd BufRead,BufNewFile *.js set shiftwidth=2
autocmd BufRead,BufNewFile *.js set tabstop=2
autocmd BufRead,BufNewFile *.js set textwidth=100
" }}}
" {{{ JSON
autocmd BufRead,BufNewFile *.json set expandtab
autocmd BufRead,BufNewFile *.json set foldmethod=indent
autocmd BufRead,BufNewFile *.json set shiftwidth=2
autocmd BufRead,BufNewFile *.json set tabstop=2
autocmd BufRead,BufNewFile *.json set textwidth=0
" }}}
" {{{ YAML file
autocmd BufRead,BufNewFile *.yml set expandtab
autocmd BufRead,BufNewFile *.yml set foldmethod=indent
autocmd BufRead,BufNewFile *.yml set shiftwidth=2
autocmd BufRead,BufNewFile *.yml set tabstop=2
autocmd BufRead,BufNewFile *.yml set textwidth=100
autocmd BufRead,BufNewFile *.yaml set expandtab
autocmd BufRead,BufNewFile *.yaml set foldmethod=indent
autocmd BufRead,BufNewFile *.yaml set shiftwidth=2
autocmd BufRead,BufNewFile *.yaml set tabstop=2
autocmd BufRead,BufNewFile *.yaml set textwidth=100
" }}}
" {{{ .pypirc
autocmd BufRead,BufNewFile .pypirc set ft=dosini
autocmd BufRead,BufNewFile *.yml set shiftwidth=2
autocmd BufRead,BufNewFile *.yml set tabstop=2
" }}}
" }}}

" For airline
let g:airline_theme='angr'
let g:airline_solarized_bg='dark'

" {{{ Key bindings
nnoremap                <F3>              /<c-r><c-w>

" Bindings for tabs
nnoremap <silent>       <leader>th      :tabfirst<CR>
nnoremap <silent>       <leader>tk      :tabnext<CR>
nnoremap <silent>       <leader>tj      :tabprev<CR>
nnoremap <silent>       <leader>tl      :tablast<CR>
nnoremap                <leader>tt      :tabedit<Space>
nnoremap <silent>       <leader>tn      :tabnext<Space>
nnoremap <silent>       <leader>tm      :tabm<Space>
nnoremap <silent>       <leader>td      :tabclose<CR>

nnoremap <silent>       <leader>w       :w<CR>
nnoremap <silent>       <leader>ck      :cclose<CR>
nnoremap <silent>       <leader>cn      :cnext<CR>
nnoremap <silent>       <leader>co      :copen<CR>
nnoremap                <leader>f       :Ack<SPACE>"<C-r><C-w>"<SPACE>
nnoremap                <leader>vg      :vimgrep<SPACE>/<C-R><C-W>/<SPACE>**/*.py
nnoremap <silent>       <leader>er      :vsplit ~/.vimrc<CR>
nnoremap                <leader>st      :tag<SPACE>
nnoremap                <leader>cs      :colorscheme<SPACE>
nnoremap <silent>       <ESC><ESC>      :nohlsearch<CR>

" Copy file path in current buffer
nnoremap <silent>       <leader>cfp     :let @+ = expand("%")<CR>
" }}}

command! MakeTags !ctags -R

" {{{ CtrlP
set wildignore+=*.swp,*.pyc
let g:ctrlp_custom_ignore = 'build\|dist\|.git\|.env\|node_modules\|htmlcov\|target/html'

"nnoremap                <leader>t       :CtrlPBufTag<CR>
nnoremap                <leader>l       :CtrlPBuffer<CR>
" }}}

" {{{ NERDTree
let g:NERDTreeWinPos = "right"
let NERDTreeIgnore=['\.pyc$', '\~$', '\.swp', '\.venv', '\.vscode', '\.idea', '\.git$']
let NERDTreeShowHidden=1

nnoremap <silent>       <C-\>           :NERDTreeToggle<CR>
nnoremap <silent>       <C-A-F>         :NERDTreeFind<CR>
" }}}

function! QToggleListCharsShow()
    if exists("s:c_set_list") == 0
        let s:c_set_list = 0
    endif
    let state = { 0: "set list", 1: "set nolist" }
    execute state[s:c_set_list]
    let s:c_set_list = -(s:c_set_list - 1)
endfunction
nnoremap <silent>       <F4>            :call QToggleListCharsShow()<CR>


" {{{ JavaScript
let g:javascript_plugin_jsdoc = 1
" }}}

" {{{ Neovim LSP
let g:LanguageClient_serverCommands = {
    \ 'python': ['pyls', '-vv', '--log-file', '~/pyls.log'],
    \ }

:lua <<EOF
local on_attach_vim = function(client)
  require'completion'.on_attach(client)
  require'diagnostic'.on_attach(client)
end

local nvim_lsp = require'nvim_lsp'
nvim_lsp.pyls.setup{
    on_attach = on_attach_vim,
    configurationSources = {'flake8'},
    plugins = {
        jedi_completion = {
            enabled = true
        },
        jedi_hover = {
            enabled = true
        },
        jedi_references = {
            enabled = true
        },
        jedi_signature_help = {
            enabled = true
        },
        jedi_symbols = {
            enabled = true,
            all_scopes = true
        },
        mccabe = {
            enabled = true,
            threshold = 15
        },
        preload = {
            enabled = true
        },
        pycodestyle = {
            enabled = false
        },
        pydocstyle = {
            enabled = false
        },
        pyflakes = {
            enabled = false
        },
        rope_completion = {
            enabled = true
        },
        yapf = {
            enabled = true
        },
        flake8 = {
            enabled = true,
            executable = 'flake8'
        }
    }
}
nvim_lsp.tsserver.setup{
    on_attach = on_attach_vim
}
nvim_lsp.gopls.setup{
    on_attach = on_attach_vim
}
nvim_lsp.yamlls.setup{
    on_attach = on_attach_vim
}
nvim_lsp.dockerls.setup{
    on_attach = on_attach_vim
}
nvim_lsp.clangd.setup{
    on_attach = on_attach_vim
}
EOF

nnoremap <silent>   gd          <cmd>lua vim.lsp.buf.declaration()<CR>
nnoremap <silent>   <c-]>       <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent>   K           <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent>   gD          <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent>   <c-k>       <cmd>lua vim.lsp.buf.signature_help()<CR>
nnoremap <silent>   1gD         <cmd>lua vim.lsp.buf.type_definition()<CR>
nnoremap <silent>   gr          <cmd>lua vim.lsp.buf.references()<CR>
nnoremap <silent>   g0          <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent>   ,t          <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent>   gW          <cmd>lua vim.lsp.buf.workspace_symbol()<CR>

" {{{ completion-nvim
" Use <Tab> and <S-Tab> to navigate through popup menu
inoremap <expr>     <Tab>       pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr>     <S-Tab>     pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect

" Avoid showing message extra message when using completion
set shortmess+=c
" }}}

" {{{ diagnostic
" }}}

" }}}
