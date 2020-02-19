scriptencoding utf-8
scriptversion 4

if !exists('g:forgetmenot_session_dir')
  let g:forgetmenot_session_dir = expand('~/.local/cache/vim-forget-me-not')
endif
if !exists('g:forgetmenot_instance_session_interval')
  let g:forgetmenot_instance_session_interval = 60 * 1000
endif
if !exists('g:forgetmenot_enable_tab_session')
  let g:forgetmenot_enable_tab_session = 0
endif

" TODO
" * autoload
" * delay s:init() if possible
" * g:forgetmenot_enable_tab_session
" * Save tab-local session (optional)
" * Save window-local session (optional)

function! s:save_instance_session(_timer) abort
  let dir = expand(g:forgetmenot_session_dir .. '/instance')
  if !isdirectory(dir)
    call s:echo_error('No such directory: ' .. dir)
  endif
  execute 'mksession!' dir .. '/Session.vim'
endfunction

function! s:echo_error(msg) abort
  echohl ErrorMsg
  echomsg 'forget-me-not:' a:msg
  echohl None
endfunction

function! s:exception(msg) abort
  return #{
  \ _tag: 'forget_me_not',
  \ msg: a:msg,
  \}
endfunction

function! s:instance_acquire_lock(retry, interval) abort
  let dir = expand(g:forgetmenot_session_dir .. '/lock/instance')
  let retry = a:retry
  try
    call mkdir(dir)
  catch
    if retry <= 0
      throw s:exception('failed to acquire lock')
    endif
    let retry -= 1
  endtry
endfunction

function! s:instance_release_lock() abort
  let dir = expand(g:forgetmenot_session_dir .. '/lock/instance')
  call delete(dir, 'd')
endfunction

function! s:instance_add(pid) abort
  let file = expand(g:forgetmenot_session_dir .. '/instances.json')
  call s:instance_acquire_lock(3, 500)
  try
    let json = json_decode(readfile(file)->join(''))
    let json.instances = json.instances->add(a:pid)->sort('n')->uniq()
    call writefile(json, file)
  finally
    call s:instance_release_lock()
  endtry
endfunction

function! s:cmd_recover(args) abort
  " TODO
endfunction

function! s:cmd_forget_me_not(args) abort
  if empty(a:args) || a:args[0] =~# '\v^-?help$'
    help :ForgetMeNot
    return
  endif
  if a:args[0] ==# 'recover'
    call s:cmd_recover(a:args[1:])
  endif
endfunction

function! s:complete_forget_me_not(arglead, cmdline, curpos) abort
  " TODO
  return ['-help', 'recover']
endfunction

command! -bar -nargs=* -complete=customlist,s:complete_forget_me_not ForgetMeNot
\   call s:cmd_forget_me_not([<f-args>])


function! s:init() abort
  try
    " Create directories
    let dir = expand(g:forgetmenot_session_dir)
    silent! call mkdir(dir, 'p')
    silent! call mkdir(dir .. '/instance')

    " Save a instance session every 'g:forgetmenot_instance_session_interval'
    call timer_start(g:forgetmenot_instance_session_interval, function('s:save_instance_session'))

    " TODO
    " Prompt to recover the previous instance session if the vim instance exited abnormally.
    " Skip recovering when user typed 's'.

    " Add this instance to instances.json
    call s:instance_add(getpid())
  catch
    " TODO: Disable plugin
    call s:echo_error('Disabling plugin because initialization failed...')
    call s:echo_error('Error: ' + v:exception)
    call s:echo_error('Where: ' + v:throwpoint)
  endtry
endfunction

call s:init()
