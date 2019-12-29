" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

" Plugins
Plug 'w0rp/ale'
Plug 'neoclide/coc.nvim', {'tag': '*', 'do': './install.sh'}
Plug 'editorconfig/editorconfig-vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --bin' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/goyo.vim', { 'for': 'markdown' }
"Plug 'itchyny/lightline.vim'
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'joshdick/onedark.vim'
Plug 'wellle/targets.vim'
Plug 'bling/vim-airline'
"Plug 'bagrat/vim-buffet'
Plug 'tpope/vim-commentary'
Plug 'junegunn/vim-easy-align'
Plug 'tpope/vim-fugitive'
Plug 'terryma/vim-multiple-cursors'
Plug 'sheerun/vim-polyglot'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tmux-plugins/vim-tmux-focus-events'
Plug 'christoomey/vim-tmux-navigator'

" load vim-devicons last so plugins are patched
Plug 'ryanoasis/vim-devicons'

" Initialize plugin system
" Automatically executes `filetype plugin indent on` and `syntax enable`
call plug#end()

""""""""""""""""""""
" non-Plugin stuff "
""""""""""""""""""""

" be iMproved, enter the current millenium
set nocompatible

" one-dark for the win
colorscheme onedark

" show line numbers in vim
set number

" show relative line numbers
set relativenumber

" highlight all matches
set hlsearch

" hide '-- INSERT --'
set noshowmode

" search down into subfolders, provides tab-completion for all file-related tasks
set path+=**

" display all matching files when we tab complete
set wildmenu

" fold functions by syntax
set foldmethod=syntax

" allow project specific vimrc
set exrc

" be more secure against project specific vimrc
set secure

" enable mouse support
set mouse=a

" use Comma as Leader key
let mapleader = ","

" <F11> - toggle paste option
set pastetoggle=<F11>

" <CR> - clear previous search highlight
nnoremap <CR> :noh<CR><CR>

" <Leader>q - close buffer without killing window
map <Leader>q :bp<bar>sp<bar>bn<bar>bd<CR>

"""""""
" ALE "
"""""""

let g:ale_sign_error = '❌'
let g:ale_sign_warning = '⚠️'
let g:ale_linters = {
\  'javascript': [],
\  'typescript': [],
\}
let g:ale_linters_ignore = {}
let g:ale_fixers = {
\  '*': ['remove_trailing_lines', 'trim_whitespace'],
\  'javascript': ['prettier', 'eslint'],
\  'typescript': ['prettier', 'tslint'],
\}

nmap <silent> [c <Plug>(ale_previous_wrap)
nmap <silent> ]c <Plug>(ale_next_wrap)
nmap <F6> <Plug>(ale_fix)

"""""""
" COC "
"""""""

let g:coc_global_extensions = [
\  'coc-eslint',
\  'coc-json',
\  'coc-pairs',
\  'coc-prettier',
\  'coc-rust-analyzer',
\  'coc-snippets',
\  'coc-tslint-plugin',
\  'coc-tsserver',
\  ]

" if hidden is not set, TextEdit might fail.
set hidden

" Some servers have issues with backup files
" see https://github.com/neoclide/coc.nvim/issues/649
set nobackup
set nowritebackup

" Better display for messages
set cmdheight=2

" You will have bad experience for diagnostic messages when it's default 4000.
set updatetime=300

" don't give |ins-completion-menu| messages.
set shortmess+=c

" always show signcolumns
set signcolumn=yes

" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
inoremap <silent><expr> <TAB>
\  pumvisible() ? "\<C-n>" :
\  <SID>check_back_space() ? "\<TAB>" :
\  coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" Coc only does snippet and additional edit on confirm.
inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
" Or use `complete_info` if your vim support it, like:
" inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"

" Use `[g` and `]g` to navigate diagnostics
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Highlight symbol under cursor on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Remap for format selected region
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Remap for do codeAction of selected region, ex: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap for do codeAction of current line
nmap <leader>ac  <Plug>(coc-codeaction)
" Fix autofix problem of current line
nmap <leader>qf  <Plug>(coc-fix-current)

" Create mappings for function text object, requires document symbols feature of languageserver.
xmap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap if <Plug>(coc-funcobj-i)
omap af <Plug>(coc-funcobj-a)

" Use <C-r> for select selections ranges, needs server support, like: coc-tsserver, coc-python
nmap <silent> <C-r> <Plug>(coc-range-select)
xmap <silent> <C-r> <Plug>(coc-range-select)

" Use `:Format` to format current buffer
command! -nargs=0 Format :call CocAction('format')

" Use `:Fold` to fold current buffer
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" use `:OR` for organize import of current buffer
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Add status line support, for integration with other plugin, checkout `:h coc-status`
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

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

" Other commands
command! -nargs=0 Prettier :CocCommand prettier.formatFile
command! -nargs=0 ESLint   :CocCommand eslint.executeAutofix

""""""""""""""""
" EditorConfig "
""""""""""""""""

let g:EditorConfig_exclude_patterns = ['fugitive://.*', 'scp://.*']

"""""""
" fzf "
"""""""

nnoremap <C-p> :Files<CR>
nnoremap <Leader>b :Buffers<CR>
nnoremap <Leader>h :History<CR>
nnoremap <Leader>t :BTags<CR>
nnoremap <Leader>T :Tags<CR>

"""""""""""""""""
" lightline.vim "
"""""""""""""""""

let g:lightline = {
\  'component': {
\    'lineinfo': ' %3l:%-2v',
\  },
\  'component_function': {
\    'readonly': 'LightlineReadonly',
\    'fugitive': 'LightlineFugitive'
\  },
\  'separator': { 'left': "\ue0b0", 'right': "\ue0b2" },
\  'subseparator': { 'left': "\ue0b1", 'right': "\ue0b3" },
\  'enable': {
\    'tabline': 0
\  }
\}

function! LightlineReadonly()
  return &readonly ? '' : ''
endfunction

function! LightlineFugitive()
  if exists('*fugitive#head')
    let branch = fugitive#head()
    return branch !=# '' ? ''.branch : ''
  endif
  return ''
endfunction

""""""""""""
" NerdTree "
""""""""""""

let NERDTreeShowHidden=1

map <Leader>n :NERDTreeToggle<CR>
map <Leader>m :NERDTreeFind<CR>

" Open NERDTree automatically when vim starts up on opening a directory
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | exe 'cd '.argv()[0] | endif

" Close vim if the only window left open is a NERDTree
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

""""""""""""
" Prettier "
""""""""""""

let g:prettier#autoformat = 0

"""""""""""""
" UltraSnip "
"""""""""""""

" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

"""""""""""""""
" vim-airline "
"""""""""""""""

let g:airline_theme='onedark'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'

""""""""""""""
" vim-buffet "
""""""""""""""

"let g:buffet_always_show_tabline = 0
"let g:buffet_show_index = 1
"let g:buffet_powerline_separators = 1
"let g:buffet_tab_icon = "\uf00a"
"let g:buffet_left_trunc_icon = "\uf0a8"
"let g:buffet_right_trunc_icon = "\uf0a9"

" Tab shortcuts
"nmap <leader>1 <Plug>BuffetSwitch(1)
"nmap <leader>2 <Plug>BuffetSwitch(2)
"nmap <leader>3 <Plug>BuffetSwitch(3)
"nmap <leader>4 <Plug>BuffetSwitch(4)
"nmap <leader>5 <Plug>BuffetSwitch(5)
"nmap <leader>6 <Plug>BuffetSwitch(6)
"nmap <leader>7 <Plug>BuffetSwitch(7)
"nmap <leader>8 <Plug>BuffetSwitch(8)
"nmap <leader>9 <Plug>BuffetSwitch(9)
"nmap <leader>0 <Plug>BuffetSwitch(10)

" Navigation shortcuts
noremap <Tab> :bn<CR>
noremap <S-Tab> :bp<CR>
"noremap <Leader><Tab> :Bw<CR>
"noremap <Leader><S-Tab> :Bw!<CR>
"noremap <C-t> :tabnew split<CR>

""""""""""""""""""
" vim-easy-align "
""""""""""""""""""

" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)


" syntax:ssDquote
