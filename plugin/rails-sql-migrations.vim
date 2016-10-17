" rails-sql-migrations.vim - rails.vim helper for generating SQL migrations
" for Rails projects
" Author: Josh Branchaud <http://joshbranchaud.com>
" Version: 0.2

if exists('g:loaded_rails_sql_migrations') || &cp || v:version < 700
  finish
endif
let g:loaded_rails_sql_migrations = 1


" Introspection

" http://stackoverflow.com/questions/24027506/get-a-vim-scripts-snr
function! s:GetScriptNumber(script_name)
  redir => scriptnames
  silent! scriptnames
  redir END

  for script in split(l:scriptnames, "\n")
    if l:script =~ a:script_name
      return str2nr(split(l:script, ":")[0])
    endif
  endfor

  return -1
endfunction

function! s:BuildRailsVimFunction(func_name, args) abort
  let vim_rails_autoload_snr = s:GetScriptNumber("autoload/rails.vim")
  let coerced_args = []
  for arg in a:args
    if type(arg) == type("")
      let coerced_args += ['"'.arg.'"']
    else
      let coerced_args += [arg]
    endif
  endfor
  let args_str = join(coerced_args, ",")
  return printf("<SNR>%d_%s(%s)", vim_rails_autoload_snr, a:func_name, args_str)
endfunction


" Rails.vim Functions

function! s:app_migration(file) dict
  let func_str = s:BuildRailsVimFunction("app_migration", [a:file])
  return eval(func_str)
endfunction

function! s:error(str)
  let func_str = s:BuildRailsVimFunction("error", [a:str])
  return eval(func_str)
endfunction

function! s:findcmdfor(cmd) abort
  let func_str = s:BuildRailsVimFunction("findcmdfor", [a:cmd])
  return eval(func_str)
endfunction

function! s:migrationList(A,L,P)
  let func_str = s:BuildRailsVimFunction("migrationList", [a:A, a:L, a:P])
  return eval(func_str)
endfunction

function! s:open(cmd, file) abort
  let func_str = s:BuildRailsVimFunction("open", [a:cmd, a:file])
  return eval(func_str)
endfunction


" Utility

function! s:sub(str,pat,rep)
  return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfunction


" Functions adapted from Rails.vim

map <SID>xx <SID>xx
let s:sid = s:sub(maparg("<SID>xx"),'xx$','')
unmap <SID>xx

function! s:sqlList(A,L,P)
  return s:migrationList(a:A, a:L, a:P)
endfunction

function! s:addfilecmds(type)
  let l = s:sub(a:type,'^.','\l&')
  for prefix in ['E', 'S', 'V', 'T', 'D', 'R', 'RE', 'RS', 'RV', 'RT', 'RD']
    let cplt = " -complete=customlist,".s:sid.l."List"
    exe "command! -buffer -bar ".(prefix =~# 'D' ? '-range=0 ' : '')."-nargs=*".cplt." ".prefix.l." :execute s:".l.'Edit("'.(prefix =~# 'D' ? '<line1>' : '').s:sub(prefix, '^R', '').'<bang>",<f-args>)'
  endfor
endfunction

function! s:sqlEdit(cmd,...)
  let cmd = s:findcmdfor(a:cmd)
  let arg = a:0 ? a:1 : ''
  if arg =~# '!'
    " This will totally miss the mark if we cross into or out of DST.
    let ts = localtime()
    let local = strftime('%H', ts) * 3600 + strftime('%M', ts) * 60 + strftime('%S')
    let offset = local - ts % 86400
    if offset <= -12 * 60 * 60
      let offset += 86400
    elseif offset >= 12 * 60 * 60
      let offset -= 86400
    endif
    let template = 'class ' . rails#camelize(matchstr(arg, '[^!]*')) . " < ActiveRecord::Migration\n  def up\n    execute <<-SQL\n    SQL\n  end\n\n  def down\n    execute <<-SQL\n    SQL\n  end\nend"
    return rails#buffer().open_command(a:cmd, strftime('%Y%m%d%H%M%S', ts - offset).'_'.arg, 'migration',
          \ [{'pattern': 'db/migrate/*.rb', 'template': template}])
  endif
  let migr = arg == "." ? "db/migrate" : rails#app().migration(arg)
  if migr != ''
    return s:open(cmd, migr)
  else
    return s:error("Migration not found".(arg=='' ? '' : ': '.arg))
  endif
endfunction


" Setup

function! s:SetupRailsSQLMigrations()
  call s:addfilecmds('sql')
endfunction

augroup railsSqlMigrations
  autocmd!
  autocmd User BufEnterRails
        \ if s:GetScriptNumber("autoload/rails.vim") > 0 |
        \   call s:SetupRailsSQLMigrations() |
        \ endif
augroup END

" vim:set sw=2 sts=2:
