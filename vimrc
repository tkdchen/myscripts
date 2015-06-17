set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

Plugin 'scrooloose/nerdtree'
Plugin 'mileszs/ack.vim'
Plugin 'powerline/powerline'
Plugin 'tpope/vim-fugitive'

" For snippet
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'garbas/vim-snipmate'
Plugin 'honza/vim-snippets'

Plugin 'digitaltoad/vim-jade'

" Colorschemes
Plugin 'tomasr/molokai'
Plugin 'wesQ3/wombat.vim'
Plugin 'ajh17/Spacegray.vim'
Plugin 'DAddYE/soda.vim'
Plugin 'jonathanfilip/vim-lucius'
Plugin 'ekalinin/Dockerfile.vim'
Plugin 'altercation/vim-colors-solarized'

call vundle#end()            " required

syn on
filetype plugin indent on
set expandtab
" set foldmethod=syntax
set guioptions-=T
set listchars=eol:$,tab:>-,trail:.
set nohlsearch
set smartindent
colorscheme jellybeans

set cinoptions+=(0

set t_Co=256

if has('gui_running')
    set guifont=Source\ Code\ Pro\ Regular\ 12
endif

filetype plugin on
autocmd BufRead,BufNewFile *.cpp set cindent
autocmd BufRead,BufNewFile *.cpp set expandtab
autocmd BufRead,BufNewFile *.cpp set shiftwidth=4
autocmd BufRead,BufNewFile *.cpp set tabstop=4
autocmd BufRead,BufNewFile *.c set cindent
autocmd BufRead,BufNewFile *.c set expandtab
autocmd BufRead,BufNewFile *.c set foldmethod=syntax
autocmd BufRead,BufNewFile *.c set shiftwidth=4
autocmd BufRead,BufNewFile *.c set tabstop=4
autocmd BufRead,BufNewFile *.h set cindent
autocmd BufRead,BufNewFile *.h set expandtab
autocmd BufRead,BufNewFile *.h set shiftwidth=4
autocmd BufRead,BufNewFile *.h set tabstop=4
autocmd BufRead,BufNewFile *.html set noexpandtab
autocmd BufRead,BufNewFile *.html set shiftwidth=2
autocmd BufRead,BufNewFile *.html set syntax=htmldjango
autocmd BufRead,BufNewFile *.html set tabstop=2
autocmd BufRead,BufNewFile *.html set textwidth=0
autocmd BufRead,BufNewFile *.json set expandtab
autocmd BufRead,BufNewFile *.json set shiftwidth=2
autocmd BufRead,BufNewFile *.json set tabstop=2
autocmd BufRead,BufNewFile *.js set expandtab
autocmd BufRead,BufNewFile *.js set foldmethod=indent
autocmd BufRead,BufNewFile *.js set shiftwidth=2
autocmd BufRead,BufNewFile *.js set tabstop=2
autocmd BufRead,BufNewFile *.markdown set foldmethod=indent
autocmd BufRead,BufNewFile *.markdown set shiftwidth=4
autocmd BufRead,BufNewFile *.markdown set syntax=markdown
autocmd BufRead,BufNewFile *.markdown set tabstop=4
autocmd BufRead,BufNewFile *.markdown set textwidth=80
autocmd BufRead,BufNewFile *.md set expandtab
autocmd BufRead,BufNewFile *.md set foldmethod=indent
autocmd BufRead,BufNewFile *.md set shiftwidth=4
autocmd BufRead,BufNewFile *.md set syntax=markdown
autocmd BufRead,BufNewFile *.md set tabstop=4
autocmd BufRead,BufNewFile *.md set textwidth=80
autocmd BufRead,BufNewFile *.py set expandtab
autocmd BufRead,BufNewFile *.py set foldmethod=indent
autocmd BufRead,BufNewFile *.py set shiftwidth=4
autocmd BufRead,BufNewFile *.py set tabstop=4
autocmd BufRead,BufNewFile *.py set textwidth=79
autocmd BufRead,BufNewFile *.rst set textwidth=80
autocmd BufRead,BufNewFile *.txt set syntax=rst
autocmd BufRead,BufNewFile *.txt set textwidth=80
autocmd BufRead,BufNewFile *.xml set expandtab
autocmd BufRead,BufNewFile *.xml set foldmethod=indent
autocmd BufRead,BufNewFile *.xml set shiftwidth=4
autocmd BufRead,BufNewFile *.xml set tabstop=4

" Ruby
autocmd BufRead,BufNewFile *.rb set expandtab
autocmd BufRead,BufNewFile *.rb set foldmethod=indent
autocmd BufRead,BufNewFile *.rb set shiftwidth=2
autocmd BufRead,BufNewFile *.rb set tabstop=2
autocmd BufRead,BufNewFile *.rb set textwidth=100


function! QToggleListCharsShow()
    if exists("s:c_set_list") == 0
        let s:c_set_list = 0
    endif
    let state = { 0: "set list", 1: "set nolist" }
    execute state[s:c_set_list]
    let s:c_set_list = -(s:c_set_list - 1)
endfunction

map <F2> :echo strftime('%c')<CR>
map <F3> :!acpi -b<CR>
map <F4> :call QToggleListCharsShow()<CR>
nnoremap <silent> <F5> :TlistToggle<CR>

map <C-r>c :call RstHeadComplete()<CR>

" Window operations
map <C-w>0 :close<CR>
map <C-w>1 :only<CR>
map <C-w>c :copen<CR>
map <C-w>l :cclose<CR>

abbr rd rpmdiff
abbr mb messagebus

function! QListDefinitions()
    let s:line_num = 1
    let s:total_lines_num = line("$")
    while s:line_num <= s:total_lines_num
        let s:line_str = getline(s:line_num)
        if s:line_str =~ '^ *\(class\|def\) \w\+'
            echo printf("%6d: %s", s:line_num, s:line_str)
        endif
        let s:line_num += 1
    endwhile
endfunction

" NERDTree
" Single clike to expand and collaps directory
let NERDTreeMouseMode=2

" Following functions are specific to particular projects
