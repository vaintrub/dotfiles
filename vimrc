set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where vundle should install plugins
"call vundle#begin('~/some/path/here')

" let vundle manage vundle, required
plugin 'vundlevim/vundle.vim'

" the following are examples of different formats supported.
" keep plugin commands between vundle#begin/end.
" plugin on github repo
plugin 'tpope/vim-fugitive'
plugin 'dracula/vim', { 'name': 'dracula' }
" plugin from http://vim-scripts.org/vim/scripts.html
" plugin 'l9'
" git plugin not hosted on github
plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
" plugin 'file:///home/gmarik/path/to/plugin'
" the sparkup vim script is in a subdirectory of this repo called vim.
" pass the path to set the runtimepath properly.
" install l9 and avoid a naming conflict if you've already installed a
" different version somewhere else.
" plugin 'ascenator/l9', {'name': 'newl9'}

plugin 'flazz/vim-colorschemes'
plugin 'tpope/vim-surround'
" all of your plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" to ignore plugin indent changes, instead use:
"filetype plugin on
"
" brief help
" :pluginlist       - lists configured plugins
" :plugininstall    - installs plugins; append `!` to update or just :pluginupdate
" :pluginsearch foo - searches for foo; append `!` to refresh local cache
" :pluginclean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for faq
" put your non-plugin stuff after this line




" настройки табов для python, согласно рекоммендациям
set tabstop=4 
set shiftwidth=4
set smarttab
set expandtab "ставим табы пробелами
set softtabstop=4 "4 пробела в табе
set colorcolumn=80
" автоотступ
set autoindent
" подсвечиваем все что можно подсвечивать
let python_highlight_all = 1
let perl_sub_signatures = 1
" включаем 256 цветов в терминале, мы ведь работаем из иксов?
" нужно во многих терминалах, например в gnome-terminal
set t_co=256

" перед сохранением вырезаем пробелы на концах (только в .py файлах)
autocmd bufwritepre *.py normal m`:%s/\s\+$//e ``
" в .py файлах включаем умные отступы после ключевых слов
autocmd bufread *.py set smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class

syntax on "включить подсветку синтаксиса

set nu "включаем нумерацию строк
set mousehide "спрятать курсор мыши когда набираем текст
set mouse=a "включить поддержку мыши
set termencoding=utf-8 "кодировка терминала
set novisualbell "не мигать 
set t_vb= "не пищать! (опции 'не портить текст', к сожалению, нету)
" удобное поведение backspace
set backspace=indent,eol,start whichwrap+=<,>,[,]
" вырубаем черточки на табах
set showtabline=1

" переносим на другую строчку, разрываем строки
set wrap
set linebreak

" вырубаем .swp и ~ (резервные) файлы
set nobackup
set noswapfile
set encoding=utf-8 " кодировка файлов по умолчанию
set fileencodings=utf8,cp1251

set clipboard=unnamed
set ruler

set hidden
nnoremap <c-n> :bnext<cr>
nnoremap <c-p> :bprev<cr>

" выключаем звук в vim
set visualbell t_vb=

"переключение табов по cmd+number для macvim
if has("gui_macvim")
  " press ctrl-tab to switch between open tabs (like browser tabs) to 
  " the right side. ctrl-shift-tab goes the other way.
  noremap <c-tab> :tabnext<cr>
  noremap <c-s-tab> :tabprev<cr>

  " switch to specific tab numbers with command-number
  noremap <d-1> :tabn 1<cr>
  noremap <d-2> :tabn 2<cr>
  noremap <d-3> :tabn 3<cr>
  noremap <d-4> :tabn 4<cr>
  noremap <d-5> :tabn 5<cr>
  noremap <d-6> :tabn 6<cr>
  noremap <d-7> :tabn 7<cr>
  noremap <d-8> :tabn 8<cr>
  noremap <d-9> :tabn 9<cr>
  " command-0 goes to the last tab
  noremap <d-0> :tablast<cr>
endif

"set guifont=monaco:h18
":set number
set termguicolors
let g:dracula_italic = 0
let g:dracula_colorterm = 0
colorscheme dracula_bold
