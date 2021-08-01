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

colorscheme base16-tomorrow-night

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
local lsp_config_callback = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }
  buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)

  -- Set some keybinds conditional on server capabilities
  if client.resolved_capabilities.document_formatting then
    buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
  end
  if client.resolved_capabilities.document_range_formatting then
    buf_set_keymap("v", "<space>f", "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
  end

  -- Set autocommands conditional on server_capabilities
  if client.resolved_capabilities.document_highlight then
    vim.api.nvim_exec([[
      hi LspReferenceRead cterm=bold ctermbg=red guibg=LightYellow
      hi LspReferenceText cterm=bold ctermbg=red guibg=LightYellow
      hi LspReferenceWrite cterm=bold ctermbg=red guibg=LightYellow
      augroup lsp_document_highlight
        autocmd! * <buffer>
        autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
        autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]], false)
  end
end

local on_attach_handler = function(client, bufnr)
  require'completion'.on_attach(client, bufnr)
  lsp_config_callback(client, bufnr)
end

local nvim_lsp = require'lspconfig'
nvim_lsp.pyright.setup{
    on_attach = on_attach_handler
}
nvim_lsp.tsserver.setup{
    on_attach = on_attach_handler
}
nvim_lsp.gopls.setup{
    on_attach = on_attach_handler,
    settings = {
        gopls = {
            analyses = {
                unusedparams = true
            },
            staticcheck = true
        }
    }
}
nvim_lsp.yamlls.setup{
    on_attach = on_attach_handler
}
nvim_lsp.dockerls.setup{
    on_attach = on_attach_handler
}
nvim_lsp.clangd.setup{
    on_attach = on_attach_handler
}
nvim_lsp.bashls.setup{
    on_attach = on_attach_handler
}
EOF

" {{{ completion-nvim
" Use <Tab> and <S-Tab> to navigate through popup menu
inoremap <expr>     <Tab>       pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr>     <S-Tab>     pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect

" Avoid showing message extra message when using completion
set shortmess+=c
" }}}

" }}}
