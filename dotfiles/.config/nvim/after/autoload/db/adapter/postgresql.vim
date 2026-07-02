" Override dadbod's default table listing to show all schemas
" (fixes Redshift cross-schema browsing)
function! db#adapter#postgresql#tables(url) abort
  return db#systemlist(
    \ db#adapter#postgresql#filter(a:url) + ['--no-psqlrc', '-tA', '-c',
    \ "SELECT table_schema || '.' || table_name FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_internal', 'pg_toast', 'pg_temp_1') AND table_type IN ('BASE TABLE', 'VIEW') ORDER BY 1"])
endfunction
