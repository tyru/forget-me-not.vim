scriptencoding utf-8
scriptversion 4

if !exists('g:forgetmenot_base_dir')
  let g:forgetmenot_base_dir = '~/.local/cache/vim-forget-me-not'
endif
if !exists('g:forgetmenot_instance_session_interval')
  let g:forgetmenot_instance_session_interval = 60 * 1000
endif
if !exists('g:forgetmenot_named_session_options')
  let g:forgetmenot_named_session_options =
  \ 'blank,curdir,folds,help,localoptions,options,tabpages,terminal,winsize'
endif
if !exists('g:forgetmenot_list_datetime_format')
  let g:forgetmenot_list_datetime_format = '%c'
endif


command! -bar -nargs=* -complete=customlist,forget_me_not#complete_forget_me_not
\   ForgetMeNot call forget_me_not#cmd_forget_me_not([<f-args>])


function! s:current_running_dir() abort
  return expand(g:forgetmenot_base_dir .. '/running/' .. getpid())
endfunction

function! s:save_instance_session(_timer) abort
  let dir = s:current_running_dir()
  if !isdirectory(dir)
    call s:echo_error('No such directory: ' .. dir)
  endif
  execute 'mksession!' dir .. '/Session.vim'
endfunction

function! s:delete_current_instance() abort
  call delete(s:current_running_dir(), 'rf')
endfunction

function! s:init() abort
  " Save a instance session every 'g:forgetmenot_instance_session_interval'
  call mkdir(s:current_running_dir(), 'p')
  call timer_start(g:forgetmenot_instance_session_interval, function('s:save_instance_session'))
  augroup forget-me-not
    autocmd!
    autocmd VimLeavePre * call s:delete_current_instance()
  augroup END
endfunction

call s:init()
