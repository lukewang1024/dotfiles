" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

" Plugins
Plug 'airblade/vim-gitgutter', { 'branch': 'main' }
Plug 'christoomey/vim-tmux-navigator'
Plug 'editorconfig/editorconfig-vim'
Plug 'joshdick/onedark.vim', { 'branch': 'main' }
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/goyo.vim', { 'for': 'markdown' }
Plug 'junegunn/vim-easy-align'
Plug 'lambdalisue/fern-git-status.vim'
Plug 'lambdalisue/fern-renderer-nerdfont.vim'
Plug 'lambdalisue/fern.vim'
Plug 'lambdalisue/glyph-palette.vim'
Plug 'lambdalisue/nerdfont.vim'
Plug 'LumaKernel/fern-mapping-fzf.vim'
Plug 'mg979/vim-visual-multi'
Plug 'neoclide/coc.nvim', { 'branch': 'release' }
Plug 'ojroques/vim-oscyank'
Plug 'rrethy/vim-hexokinase', { 'do': 'make hexokinase' }
Plug 'sheerun/vim-polyglot'
Plug 'tmux-plugins/vim-tmux-focus-events'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'w0rp/ale'
Plug 'wellle/targets.vim'

" tabline
"Plug 'bagrat/vim-buffet'
Plug 'bling/vim-airline'
"Plug 'itchyny/lightline.vim'

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
if !has('nvim')
  set pastetoggle=<F11>
endif

" <CR> - clear previous search highlight
nnoremap <silent> <CR> :noh<CR><CR>

" <Leader>q - close the current buffer
nnoremap <Leader>q :bd<CR>

" <Leader>Q - close all buffers but the current one
nnoremap <Leader>Q :%bd \| e#<CR>

" <Leader>s - search selected text in current buffer
nnoremap <Leader>s /<C-r>"<CR>
vnoremap <Leader>s y/<C-r>"<CR>

" <Leader>S - search selected text in all files
nnoremap <Leader>S :Ag <C-r>"<CR>
vnoremap <Leader>S y:Ag <C-r>"<CR>

" Check change history of file in current buffer
function! s:GitLogP(fil)
  if (a:fil == '')
    echo 'Current buffer is not a file.'
    return
  endif
  abo new
  exe '0read ! git log -p ' . a:fil
  setlocal noma ro ts=8 tw=0 nowrap syn=diff ft=diff
  setlocal buftype=nofile noswapfile bufhidden=delete
  go
endfunction
command! GitLogP call s:GitLogP(expand("%"))

" More logical binding for 'Y' and using system clipboard with <Leader>
noremap Y y$
noremap <Leader>y "*y
noremap <Leader>yy "*yy
noremap <Leader>Y "*y$
noremap <Leader>x "*x
noremap <Leader>dd "*dd
noremap <Leader>D "*D

" Resize window with Ctrl-Arrows / Ctrl-Shift-Arrows
noremap <silent> <C-Right> :vertical resize +5<CR>
noremap <silent> <C-Left> :vertical resize -5<CR>
noremap <silent> <C-Up> :resize +5<CR>
noremap <silent> <C-Down> :resize -5<CR>
noremap <silent> <C-S-Right> :vertical resize +1<CR>
noremap <silent> <C-S-Left> :vertical resize -1<CR>
noremap <silent> <C-S-Up> :resize +1<CR>
noremap <silent> <C-S-Down> :resize -1<CR>

" Zoom / Restore window
function! s:ZoomToggle() abort
  if exists('t:zoomed') && t:zoomed
    execute t:zoom_winrestcmd
    let t:zoomed = 0
  else
    let t:zoom_winrestcmd = winrestcmd()
    resize
    vertical resize
    let t:zoomed = 1
  endif
endfunction
command! ZoomToggle call s:ZoomToggle()
nnoremap <silent> <C-a> :ZoomToggle<CR>

" Quickly edit / reload .vimrc file
noremap <Leader>,e :split $MYVIMRC<CR>
noremap <Leader>,s :source $MYVIMRC<CR>
function! s:ShowVimCmdOutputInBuf(cmd)
  redir! >/tmp/vim_temp_stash
  exe a:cmd
  redir END
  abo new
  0read ! cat /tmp/vim_temp_stash
  setlocal buftype=nofile noswapfile bufhidden=delete
  go
endfunction
command! ShowLetInBuf call s:ShowVimCmdOutputInBuf('silent let')
command! ShowMapInBuf call s:ShowVimCmdOutputInBuf('silent map')

"""""""
" ALE "
"""""""

let g:ale_disable_lsp = 1
let g:ale_sign_error = '❌'
let g:ale_sign_warning = '⚠️'
let g:ale_linters = {
\  'javascript': [],
\  'javascriptreact': [],
\  'typescript': [],
\  'typescriptreact': [],
\}
let g:ale_linters_ignore = {}
let g:ale_fixers = {
\  '*': ['remove_trailing_lines', 'trim_whitespace'],
\  'javascript': ['prettier', 'eslint'],
\  'typescript': ['prettier', 'eslint'],
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
\  'coc-tsserver',
\  ]

" Copied from coc.nvim README - Start

" May need for Vim (not Neovim) since coc.nvim calculates byte offset by count
" utf-8 byte sequence
set encoding=utf-8
" Some servers have issues with backup files, see #649
set nobackup
set nowritebackup

" Having longer updatetime (default is 4000 ms = 4s) leads to noticeable
" delays and poor user experience
set updatetime=300

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved
set signcolumn=yes

" Use tab for trigger completion with characters ahead and navigate
" NOTE: There's always complete item selected by default, you may want to enable
" no select by `"suggest.noselect": true` in your configuration file
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s)
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Applying code actions to the selected code block
" Example: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap keys for applying code actions at the cursor position
nmap <leader>ac  <Plug>(coc-codeaction-cursor)
" Remap keys for apply code actions affect whole buffer
nmap <leader>as  <Plug>(coc-codeaction-source)
" Apply the most preferred quickfix action to fix diagnostic on the current line
nmap <leader>qf  <Plug>(coc-fix-current)

" Remap keys for applying refactor code actions
nmap <silent> <leader>re <Plug>(coc-codeaction-refactor)
xmap <silent> <leader>r  <Plug>(coc-codeaction-refactor-selected)
nmap <silent> <leader>r  <Plug>(coc-codeaction-refactor-selected)

" Run the Code Lens action on the current line
nmap <leader>cl  <Plug>(coc-codelens-action)

" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Remap <C-f> and <C-b> to scroll float windows/popups
if has('nvim-0.4.0') || has('patch-8.2.0750')
  nnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  nnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
  inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
  inoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
  vnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  vnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
endif

" Use CTRL-S for selections ranges
" Requires 'textDocument/selectionRange' support of language server
nmap <silent> <C-s> <Plug>(coc-range-select)
xmap <silent> <C-s> <Plug>(coc-range-select)

" Add `:Format` command to format current buffer
command! -nargs=0 Format :call CocActionAsync('format')

" Add `:Fold` command to fold current buffer
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" Add `:OR` command for organize imports of the current buffer
command! -nargs=0 OR   :call     CocActionAsync('runCommand', 'editor.action.organizeImport')

" Add (Neo)Vim's native statusline support
" NOTE: Please see `:h coc-status` for integrations with external plugins that
" provide custom statusline: lightline.vim, vim-airline
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" Mappings for CoCList
" Show all diagnostics
nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item
nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item
nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>

" Copied from coc.nvim README - End

" Other commands
command! -nargs=0 Prettier :CocCommand prettier.formatFile
command! -nargs=0 ESLint   :CocCommand eslint.executeAutofix

""""""""""""""""
" EditorConfig "
""""""""""""""""

let g:EditorConfig_exclude_patterns = ['fugitive://.*', 'scp://.*']

""""""""
" Fern "
""""""""

let g:fern#renderer = "nerdfont"

nnoremap <Leader>n :Fern .           -drawer -keep -toggle<CR>
nnoremap <Leader>N :Fern %:h         -drawer -keep<CR>
nnoremap <Leader>m :Fern . -reveal=% -drawer -keep<CR>

augroup my-glyph-palette
  autocmd! *
  autocmd FileType fern call glyph_palette#apply()
  autocmd FileType nerdtree,startify call glyph_palette#apply()
augroup END

function! Fern_mapping_fzf_customize_option(spec)
  let a:spec.options .= ' --multi'
  " Note that fzf#vim#with_preview comes from fzf.vim
  if exists('*fzf#vim#with_preview')
    return fzf#vim#with_preview(a:spec)
  else
    return a:spec
  endif
endfunction

function! Fern_mapping_fzf_before_all(dict)
  if !len(a:dict.lines)
    return
  endif
  return a:dict.fern_helper.async.update_marks([])
endfunction

function! s:reveal(dict)
  execute "FernReveal -wait" a:dict.relative_path
  execute "normal \<Plug>(fern-action-mark:set)"
endfunction

let g:Fern_mapping_fzf_file_sink = function('s:reveal')
let g:Fern_mapping_fzf_dir_sink = function('s:reveal')

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
" Prettier "
""""""""""""

let g:prettier#autoformat = 0

"""""""""""""
" UltraSnip "
"""""""""""""

" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<C-b>"
let g:UltiSnipsJumpBackwardTrigger="<C-z>"

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
"nmap <Leader>1 <Plug>BuffetSwitch(1)
"nmap <Leader>2 <Plug>BuffetSwitch(2)
"nmap <Leader>3 <Plug>BuffetSwitch(3)
"nmap <Leader>4 <Plug>BuffetSwitch(4)
"nmap <Leader>5 <Plug>BuffetSwitch(5)
"nmap <Leader>6 <Plug>BuffetSwitch(6)
"nmap <Leader>7 <Plug>BuffetSwitch(7)
"nmap <Leader>8 <Plug>BuffetSwitch(8)
"nmap <Leader>9 <Plug>BuffetSwitch(9)
"nmap <Leader>0 <Plug>BuffetSwitch(10)

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

"""""""""""""""
" vim-oscyank "
"""""""""""""""

" Yank to host clipboard with OSC52 sequence
nmap <leader>c <Plug>OSCYankOperator
nmap <leader>cc <leader>c_
vmap <leader>c <Plug>OSCYankVisual

" syntax:ssDquote
