scriptencoding utf-8
scriptversion 4

if !exists('g:forgetmenot_session_dir')
  let g:forgetmenot_session_dir = '~/.local/cache/vim-forget-me-not'
endif
if !exists('g:forgetmenot_instance_session_interval')
  let g:forgetmenot_instance_session_interval = 60 * 1000
endif
if !exists('g:forgetmenot_enable_tab_session')
  let g:forgetmenot_enable_tab_session = 0
endif
if !exists('g:forgetmenot_named_session_options')
  let g:forgetmenot_named_session_options = 'blank,curdir,folds,help,localoptions,options,tabpages,terminal,winsize'
endif

" TODO
" * autoload
" * delay s:init() if possible
" * g:forgetmenot_enable_tab_session
" * Save tab-local session (optional)
" * Save window-local session (optional)


" Dir paths

function! s:required_dirs() abort
  let dir = expand(g:forgetmenot_session_dir)
  return [
  \ dir,
  \ dir .. '/lock',
  \ dir .. '/running',
  \ dir .. '/running/' .. getpid(),
  \ dir .. '/named',
  \]
endfunction

function! s:running_dir() abort
  return expand(g:forgetmenot_session_dir .. '/running')
endfunction

function! s:current_running_dir() abort
  return expand(g:forgetmenot_session_dir .. '/running/' .. getpid())
endfunction

function! s:named_dir() abort
  return expand(g:forgetmenot_session_dir .. '/named')
endfunction


let s:created_lock_files = []

" TODO: stricter escape for a:name
function! s:acquire_lock(name, retry, interval) abort
  let name = substitute(a:name, '[/\\]', '-', 'g')
  let dir = expand(g:forgetmenot_session_dir .. '/lock/' .. name)
  for _ in range(a:retry)
    try
      call mkdir(dir)
      break
    catch
      execute 'sleep' a:interval .. 'm'
    endtry
  endfor
  if !isdirectory(dir)
    throw s:exception('failed to acquire lock')
  endif
  let l:Release = function('delete', [dir, 'd'])
  let s:created_lock_files += [l:Release]
  function! s:release() abort closure
    call l:Release()
    eval filter(s:created_lock_files, {-> v:val isnot# l:Release })
  endfunction
  return {-> l:Release()}
endfunction

function! s:echo_error(msg, hist = v:true) abort
  echohl ErrorMsg
  if a:hist
    echomsg 'forget-me-not:' a:msg
  else
    echo 'forget-me-not:' a:msg
  endif
  echohl None
endfunction

function! s:exception(msg) abort
  return 'forget-me-not: ' .. a:msg
endfunction

" 15 * 1000 = write interval
function! s:is_stale(info) abort
  let interval = g:forgetmenot_instance_session_interval + 15 * 1000
  let mtime = getftime(a:info.session_file)
  return mtime > 0 && localtime() - interval > mtime
endfunction

function! s:get_running_pid_infos() abort
  let dir = s:running_dir()
  return glob(s:running_dir() .. '/*', 1, 1)
    \->map({-> #{
    \   pid: str2nr(fnamemodify(v:val, ':t')),
    \   session_file: v:val .. '/Session.vim',
    \}})
endfunction

" TODO use popup instead of inputlist()
" TODO show brief description (buffer names?) for each pid
function! s:cmd_recover(args) abort
  let name = ''
  let stale = v:false
  let silent = v:false
  for i in range(1, len(a:args) - 1)
    let arg = a:args[i]
    if arg[0] !=# '-'
      let name = arg
      break
    endif
    if arg ==# '-stale'
      let stale = v:true
    elseif arg ==# '-silent'
      let silent = v:true
      let stale = v:true
    endif
  endfor
  if !empty(name)
    let session_file = s:named_dir() .. '/' .. name .. '/Session.vim'
    if !filereadable(session_file)
      call s:echo_error('No such named session: ' .. name)
      return
    endif
  else
    let infos = s:get_running_pid_infos()
    if stale
      let infos = infos->filter({-> s:is_stale(v:val) })
    endif
    if empty(infos)
      if !silent
        echo 'No sessions to restore.'
      endif
      return
    endif
    if stale
      call s:echo_error('Last session exited abnormally! Select a session to restore.', v:false)
    else
      echo 'Select a session to restore.'
    endif
    let list = infos->map({->
    \ printf('%s (pid was %d)', strftime(getftime(v:val.session_file)), v:val.pid) })
    let pid = inputlist(list)->str2nr()
    let session_file = infos->filter({-> v:val.pid ==# pid })->get(0, {})->get(, '')
  endif
  if !empty(session_file)
    execute 'source' session_file
  else
    echo 'No sessions to restore.'
    return
  endif
endfunction

function! s:cmd_save(args) abort
  " TODO
  call s:cmd_write(a:args)
endfunction

function! s:cmd_write(args) abort
  let name = a:args->get(1, '')
  if empty(name)
    call s:echo_error('No name specified. see help :ForgetMeNot-write')
    return
  endif
  let dir = s:named_dir() .. '/' .. name
  if isdirectory(dir) && a:args[0] !=# 'write!'
    call s:echo_error("Session '" .. name .. "' already exists. " ..
    \ "Use ':ForgetMeNot write!' to overwrite the session.")
    return
  endif
  call mkdir(dir, 'p')
  let file = dir .. '/Session.vim'
  " Acquire lock to write to the session file.
  " Because if 'name' is current session, multiple writes may occur at same time.
  let l:Release = s:acquire_lock('name-' .. name, 3, 200)
  let saved = &l:sessionoptions
  try
    let &l:sessionoptions = s:get_session_options('named')
    execute 'mksession!' file
  finally
    let &l:sessionoptions = saved
    call l:Release()
  endtry
endfunction

function! s:get_session_options(type) abort
  if a:type ==# 'named'
    return g:forgetmenot_named_session_options
  else
    throw s:exception("s:get_session_options(): unknown type '" .. a:type .. "'")
  endif
endfunction

function! s:cmd_forget_me_not(args) abort
  if empty(a:args) || a:args[0] =~# '\v^-?help$'
    help :ForgetMeNot
    return
  endif
  if a:args[0] ==# 'recover'
    call s:cmd_recover(a:args)
  elseif a:args[0] ==# 'save' || a:args[0] ==# 'save!'
    call s:cmd_save(a:args)
  elseif a:args[0] ==# 'write' || a:args[0] ==# 'write!'
    call s:cmd_write(a:args)
  else
    call s:echo_error('Unknown command: ' .. a:args[0])
  endif
endfunction

function! s:complete_forget_me_not(arglead, cmdline, curpos) abort
  " TODO
  return ['-help', 'recover', 'save', 'write']
endfunction

command! -bar -nargs=* -complete=customlist,s:complete_forget_me_not ForgetMeNot
\   call s:cmd_forget_me_not([<f-args>])


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
  try
    augroup forget-me-not
      autocmd!
    augroup END

    " Create directories
    for dir in s:required_dirs()
      call mkdir(dir, 'p')
    endfor

    " Save a instance session every 'g:forgetmenot_instance_session_interval'
    call timer_start(g:forgetmenot_instance_session_interval, function('s:save_instance_session'))
    autocmd forget-me-not VimLeavePre * call s:delete_current_instance()
    autocmd forget-me-not VimLeavePre * eval s:created_lock_files->map({-> v:val() })
  catch
    " TODO: Disable plugin
    call s:echo_error('Disabling plugin because initialization failed...')
    call s:echo_error('Error: ' .. v:exception)
    call s:echo_error('Where: ' .. v:throwpoint)
  endtry
endfunction

call s:init()
