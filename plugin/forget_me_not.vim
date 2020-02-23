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
  \ 'blank,curdir,folds,help,localoptions,tabpages,terminal,winsize'
endif
if !exists('g:forgetmenot_list_datetime_format')
  let g:forgetmenot_list_datetime_format = '%c'
endif


command! -bar -nargs=* -complete=customlist,forget_me_not#complete_forget_me_not
\   ForgetMeNot call forget_me_not#cmd_forget_me_not([<f-args>])


augroup forget-me-not
  autocmd!
augroup END

call forget_me_not#instance#init()
