scriptencoding utf-8
scriptversion 4

let s:created_lock_files = []

function! forget_me_not#util#export() abort
  return #{
  \ clean_up: function('s:clean_up'),
  \ acquire_lock: function('s:acquire_lock'),
  \ required_dirs: function('s:required_dirs'),
  \ running_dir: function('s:running_dir'),
  \ current_running_dir: function('s:current_running_dir'),
  \ named_dir: function('s:named_dir'),
  \ echo_error: function('s:echo_error'),
  \ exception: function('s:exception'),
  \}
endfunction


" Dir paths

function! s:required_dirs() abort
  let dir = expand(g:forgetmenot_base_dir)
  return [
  \ dir,
  \ dir .. '/lock',
  \ dir .. '/running',
  \ dir .. '/running/' .. getpid(),
  \ dir .. '/named',
  \]
endfunction

function! s:running_dir() abort
  return expand(g:forgetmenot_base_dir .. '/running')
endfunction

function! s:current_running_dir() abort
  return expand(g:forgetmenot_base_dir .. '/running/' .. getpid())
endfunction

function! s:named_dir() abort
  return expand(g:forgetmenot_base_dir .. '/named')
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


function! s:clean_up() abort
  eval s:created_lock_files->map({-> v:val() })
endfunction

" TODO: stricter escape for a:name
function! s:acquire_lock(name, retry, interval) abort
  let name = substitute(a:name, '[/\\]', '-', 'g')
  let dir = expand(g:forgetmenot_base_dir .. '/lock/' .. name)
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
