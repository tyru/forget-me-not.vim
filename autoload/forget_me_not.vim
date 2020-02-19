scriptencoding utf-8
scriptversion 4

" TODO
" * Save session per tab, window?
" * Integrate with git (make .git in 'lock/*', 'instance/*' directories)
" * Write test
" * Replace whole tabpages when :ForgetMeNot recover and :ForgetMeNot read
" * Allow '/' in session name?

let s:U = forget_me_not#util#export()


" 15 * 1000 = write interval
function! s:is_stale(info) abort
  let interval = g:forgetmenot_instance_session_interval + 15 * 1000
  let mtime = getftime(a:info.session_file)
  return mtime > 0 && localtime() - interval > mtime
endfunction

" TODO use popup instead of inputlist()
function! s:cmd_recover(args) abort
  let session_name = ''
  let stale = v:null
  let named = v:null
  let silent = v:false
  for i in range(1, len(a:args) - 1)
    let arg = a:args[i]
    if arg[0] !=# '-'
      let session_name = arg
      break
    endif
    if arg ==# '-stale'
      let stale = v:true
    elseif arg ==# '-unstale'
      let stale = v:false
    elseif arg ==# '-named'
      let named = v:true
    elseif arg ==# '-silent'
      let silent = v:true
    endif
  endfor
  if !empty(session_name)
    let session_file = s:U.named_dir() .. '/' .. session_name .. '/Session.vim'
    if !filereadable(session_file)
      call s:U.echo_error('No such named session: ' .. session_name)
      return
    endif
  else
    let sessions = s:get_sessions(#{named: named, stale: stale})
    if empty(sessions)
      if !silent
        echo 'No sessions to restore.'
      endif
      return
    endif
    if stale
      call s:U.echo_error('Last session exited abnormally! Select a session to restore.', v:false)
    else
      echo 'Select a session to restore.'
    endif
    let list = sessions->map({i,s -> (i + 1) .. '. ' s:format_session(s) })
    let nr = inputlist(list)->str2nr()
    let session_file = list->get(nr - 1, {})->get('session_file', '')
  endif
  if !empty(session_file)
    execute 'source' session_file
    if !empty(session_name)
      call forget_me_not#instance#set_session_name(session_name)
    endif
  else
    echo 'No sessions to restore.'
    return
  endif
endfunction

function! s:cmd_save(args) abort
  let name = a:args->get(1, '')
  let curname = forget_me_not#instance#get_session_name()
  if empty(name)
    if curname is# v:null
      call s:U.echo_error('No name specified. see help :ForgetMeNot-save')
      return
    endif
    let name = curname
    let a:args[0] = 'save!'
  elseif name ==# curname
    let a:args[0] = 'save!'
  endif
  let dir = s:U.named_dir() .. '/' .. name
  if isdirectory(dir) && a:args[0] !=# 'save!'
    call s:U.echo_error("Session '" .. name .. "' already exists. " ..
    \ "Use ':ForgetMeNot save!' to overwrite the session.")
    return
  endif
  if empty(name) && curname is# v:null
    call forget_me_not#instance#update()
    return
  endif
  call s:do_write(name, dir, v:true)
endfunction

function! s:cmd_write(args) abort
  let name = a:args->get(1, '')
  let curname = forget_me_not#instance#get_session_name()
  if empty(name)
    if curname is# v:null
      call s:U.echo_error('No name specified. see help :ForgetMeNot-write')
      return
    endif
    let name = curname
    let a:args[0] = 'write!'
  elseif name ==# curname
    let a:args[0] = 'write!'
  endif
  let dir = s:U.named_dir() .. '/' .. name
  if isdirectory(dir) && a:args[0] !=# 'write!'
    call s:U.echo_error("Session '" .. name .. "' already exists. " ..
    \ "Use ':ForgetMeNot write!' to overwrite the session.")
    return
  endif
  if empty(name) && curname is# v:null
    call forget_me_not#instance#update()
    return
  endif
  call s:do_write(name, dir, v:false)
endfunction

function! s:do_write(name, dir, is_save) abort
  call mkdir(a:dir, 'p')
  let file = a:dir .. '/Session.vim'
  " Acquire lock to write to the session file.
  " Because if 'a:name' is current session, multiple writes may occur at same time.
  let [l:Release, err] = s:U.acquire_lock('name-' .. a:name, 3, 500)
  if err isnot# v:null
    call s:U.echo_error("Another Vim is accessing '" .. a:name .. "' session: " .. err)
    return
  endif
  let saved = &l:sessionoptions
  try
    let &l:sessionoptions = s:get_session_options('named')
    execute 'mksession!' file
  finally
    let &l:sessionoptions = saved
    call l:Release()
  endtry
  if a:is_save
    call forget_me_not#instance#set_session_name(a:name)
  endif
endfunction

function! s:cmd_delete(args) abort
  let name = a:args->get(1, '')
  let curname = forget_me_not#instance#get_session_name()
  if empty(name)
    call s:U.echo_error('No name specified. see help :ForgetMeNot-delete')
    return
  elseif name ==# curname
    call s:U.echo_error('Cannot delete current session.')
    return
  endif
  " Acquire lock to write to the session file.
  " Because multiple writes may occur at same time.
  let [l:Release, err] = s:U.acquire_lock('name-' .. name, 3, 500)
  if err isnot# v:null
    call s:U.echo_error("Another Vim is accessing '" .. name .. "' session: " .. err)
    return
  endif
  try
    let dir = s:U.named_dir() .. '/' .. name
    call delete(dir, 'rf')
    if isdirectory(dir)
      call s:U.echo_error('Could not delete directory: ' .. dir)
      return
    endif
    echomsg "Deleted '" .. name .. "' session."
  finally
    call l:Release()
  endtry
endfunction

function! s:cmd_list(args) abort
  let stale = v:null
  let named = v:null
  for i in range(1, len(a:args) - 1)
    let arg = a:args[i]
    if arg[0] !=# '-'
      let name = arg
      break
    endif
    if arg ==# '-stale'
      let stale = v:true
    elseif arg ==# '-unstale'
      let stale = v:false
    elseif arg ==# '-named'
      let named = v:true
    endif
  endfor
  let sessions = s:get_sessions(#{named: named, stale: stale})
  let named_list = sessions->copy()->filter({-> v:val.named })
  let unnamed_list = sessions->copy()->filter({-> !v:val.named })
  if !empty(named_list)
    echo '--- Named ---'
    for session in named_list
      echo s:format_session(session)
    endfor
  endif
  if !empty(unnamed_list)
    echo '--- Others ---'
    for session in unnamed_list
      echo s:format_session(session)
    endfor
  endif
endfunction

" Input:
" * named (Boolean or v:null): filters return value by named (v:true) or
"                              unnamed (v:false) sessions. v:null or absent key
"                              returns all sessions.
" * stale (Boolean or v:null): filters return value by stale (v:true) or
"                              non-stale (v:false) sessions. v:null or absent key
"                              returns all sessions.
" Returns:
" * name (String): empty if named == v:false
" * pid (Number): -1 if named == v:true
" * session_file (String)
" * named (Boolean)
function! s:get_sessions(options) abort
  let named = a:options->get('named', v:null)
  let stale = a:options->get('stale', v:null)
  let sessions = []
  if named is# v:true || named is# v:null
    let sessions += glob(s:U.named_dir() .. '/*', 1, 1)
    \->map({-> #{
    \   name: fnamemodify(v:val, ':t'),
    \   pid: -1,
    \   session_file: v:val .. '/Session.vim',
    \   named: v:true,
    \}})
  endif
  if named is# v:false || named is# v:null
    let sessions += glob(s:U.running_dir() .. '/*', 1, 1)
    \->map({-> #{
    \   name: '',
    \   pid: str2nr(fnamemodify(v:val, ':t')),
    \   session_file: v:val .. '/Session.vim',
    \   named: v:false,
    \}})
  endif
  if stale isnot# v:null
    if stale
      call filter(sessions, {-> s:is_stale(v:val) })
    else
      call filter(sessions, {-> !s:is_stale(v:val) })
    endif
  endif
  return sessions
endfunction

function! s:format_session(session) abort
  let curname = forget_me_not#instance#get_session_name()
  if a:session.named
    let attrs = []
    if filereadable(a:session.session_file)
      let mtime = getftime(a:session.session_file)
      let attrs += ['updated at ' .. strftime(g:forgetmenot_list_datetime_format, mtime)]
    endif
    let current = curname is# v:null ? '  ' : curname ==# a:session.name ? '* ' : '  '
    let attrs_str = (empty(attrs) ? '' : ' (' .. attrs->join(', ') .. ')')
    return current .. a:session.name .. attrs_str
  endif
  let current = curname isnot# v:null ? '  ' : getpid() ==# a:session.pid ? '* ' : '  '
  let attrs = []
  if s:is_stale(a:session)
    let attrs += ['stale']
  endif
  if filereadable(a:session.session_file)
    let mtime = getftime(a:session.session_file)
    let attrs += ['updated at ' .. strftime(g:forgetmenot_list_datetime_format, mtime)]
  else
    let attrs += ['not saved yet']
  endif
  let name = 'instance-' .. a:session.pid
  let attrs_str = (empty(attrs) ? '' : ' (' .. attrs->join(', ') .. ')')
  return current .. name .. attrs_str
endfunction

function! s:get_session_options(type) abort
  if a:type ==# 'named'
    return g:forgetmenot_named_session_options
  else
    throw s:U.exception("s:get_session_options(): unknown type '" .. a:type .. "'")
  endif
endfunction

function! forget_me_not#cmd_forget_me_not(args) abort
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
  elseif a:args[0] ==# 'delete'
    call s:cmd_delete(a:args)
  elseif a:args[0] ==# 'list'
    call s:cmd_list(a:args)
  else
    call s:U.echo_error('Unknown command: ' .. a:args[0])
  endif
endfunction

function! forget_me_not#complete_forget_me_not(arglead, cmdline, curpos) abort
  " TODO
  return ['-help', 'recover', 'save', 'save!', 'write', 'write!', 'delete', 'list']
endfunction


function! s:init() abort
  " Create directories
  for dir in s:U.required_dirs()
    call mkdir(dir, 'p')
  endfor
endfunction

call s:init()
