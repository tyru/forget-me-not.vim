scriptencoding utf-8
scriptversion 4

let s:current_session_name = v:null
let s:U = forget_me_not#util#export()


function! forget_me_not#instance#init() abort
  " Save a instance session every 'g:forgetmenot_instance_session_interval'
  call mkdir(s:U.current_instance_dir(), 'p')
  call forget_me_not#instance#update()
  call timer_start(
  \ g:forgetmenot_instance_session_interval,
  \ function('forget_me_not#instance#update'),
  \ #{repeat: -1})
  autocmd forget-me-not VimLeavePre * call forget_me_not#instance#update()
  autocmd forget-me-not VimLeavePre * call s:delete_current_instance()
  autocmd forget-me-not VimLeavePre * call s:U.clean_up()
endfunction

function! forget_me_not#instance#get_session_name() abort
  return s:current_session_name
endfunction

function! forget_me_not#instance#set_session_name(name) abort
  if type(a:name) isnot# v:t_string && a:name isnot# v:null
    return
  endif
  call s:delete_current_instance()
  let s:current_session_name = a:name
endfunction

function! s:delete_current_instance() abort
  call delete(s:U.current_instance_dir(), 'rf')
endfunction

function! forget_me_not#instance#update(...) abort
  " Acquire lock when s:current_session_name is set.
  " Because multiple writes may occur at same time.
  if s:current_session_name is# v:null
    call mkdir(s:U.current_instance_dir(), 'p')
    let dir = s:U.current_instance_dir()
    let l:Release = {-> v:null }
  else
    let dir = s:U.named_dir() .. '/' .. s:current_session_name
    let [l:Release, err] = s:U.acquire_lock('name-' .. s:current_session_name, 3, 500)
    if err isnot# v:null
      call s:U.echo_error(
      \ "Another Vim is accessing '" .. s:current_session_name .. "' session: " .. err)
      return
    endif
  endif
  try
    if !isdirectory(dir)
      call s:U.echo_error('No such directory: ' .. dir)
    endif
    execute 'mksession!' dir .. '/Session.vim'
  finally
    call l:Release()
  endtry
endfunction
