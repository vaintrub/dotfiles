set nocompatible

" --- vim-plug bootstrap ---
" :PlugInstall / :PlugUpdate / :PlugClean
let s:plug_path = expand('~/.vim/autoload/plug.vim')
if empty(glob(s:plug_path))
  silent execute '!curl -fLo ' . s:plug_path . ' --create-dirs '
        \ . 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'mattn/emmet-vim'
Plug 'christoomey/vim-tmux-navigator'

call plug#end()

" Настройки табов для python, согласно рекоммендациям
set tabstop=4 
set shiftwidth=4
set smarttab
set expandtab " Ставим табы пробелами
set softtabstop=4 " 4 пробела в табе
set colorcolumn=80
" Автоотступ
set autoindent
" Подсвечиваем все что можно подсвечивать
let python_highlight_all = 1
let perl_sub_signatures = 1
" Включаем 256 цветов в терминале, мы ведь работаем из иксов?
" Нужно во многих терминалах, например в gnome-terminal
set t_co=256

" Перед сохранением вырезаем пробелы на концах (только в .py файлах)
autocmd bufwritepre *.py normal m`:%s/\s\+$//e ``
" В .py файлах включаем умные отступы после ключевых слов
autocmd bufread *.py set smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class

syntax on " Включить подсветку синтаксиса

set nu " Включаем нумерацию строк
set mousehide " Спрятать курсор мыши когда набираем текст
set mouse=a " Включить поддержку мыши
set termencoding=utf-8 " Кодировка терминала
set novisualbell " Не мигать 
set t_vb= " Не пищать! (опции 'не портить текст', к сожалению, нету)
" Удобное поведение backspace
set backspace=indent,eol,start whichwrap+=<,>,[,]
" Вырубаем черточки на табах
set showtabline=1

" Переносим на другую строчку, разрываем строки
set wrap
set linebreak

" Вырубаем .swp и ~ (резервные) файлы
set nobackup
set noswapfile
set encoding=utf-8 " Кодировка файлов по умолчанию
set fileencodings=utf8,cp1251

set clipboard=unnamed
set ruler

set hidden
nnoremap <c-n> :bnext<cr>
nnoremap <c-p> :bprev<cr>

" Выключаем звук в vim
set visualbell t_vb=

" Переключение табов по cmd+number для macvim
if has("gui_macvim")
  " Press ctrl-tab to switch between open tabs (like browser tabs) to 
  " The right side. ctrl-shift-tab goes the other way.
  noremap <c-tab> :tabnext<cr>
  noremap <c-s-tab> :tabprev<cr>

  " Switch to specific tab numbers with command-number
  noremap <d-1> :tabn 1<cr>
  noremap <d-2> :tabn 2<cr>
  noremap <d-3> :tabn 3<cr>
  noremap <d-4> :tabn 4<cr>
  noremap <d-5> :tabn 5<cr>
  noremap <d-6> :tabn 6<cr>
  noremap <d-7> :tabn 7<cr>
  noremap <d-8> :tabn 8<cr>
  noremap <d-9> :tabn 9<cr>
  " Command-0 goes to the last tab
  noremap <d-0> :tablast<cr>
endif

" set guifont=monaco:h18
" :set number
set termguicolors
let g:dracula_italic = 0
let g:dracula_colorterm = 0
let g:dracula_bold = 1
silent! colorscheme dracula
