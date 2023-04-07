" Heavily based on vim-notes - http://peterodding.com/code/vim/notes/
if exists('g:vim_markdown_fenced_languages')
    let s:filetype_dict = {}
    for s:filetype in g:vim_markdown_fenced_languages
        let key = matchstr(s:filetype, '[^=]*')
        let val = matchstr(s:filetype, '[^=]*$')
        let s:filetype_dict[key] = val
    endfor
else
    let s:filetype_dict = {
        \ 'c++': 'cpp',
        \ 'viml': 'vim',
        \ 'bash': 'sh',
        \ 'ini': 'dosini'
    \ }
endif

function! s:MarkdownHighlightSources(force)
    " Syntax highlight source code embedded in notes.
    " Look for code blocks in the current file
    let filetypes = {}
    for line in getline(1, '$')
        let ft = matchstr(line, '\(`\{3,}\|\~\{3,}\)\s*\zs[0-9A-Za-z_+-]*\ze.*')
        if !empty(ft) && ft !~# '^\d*$' | let filetypes[ft] = 1 | endif
    endfor
    if !exists('b:mkd_known_filetypes')
        let b:mkd_known_filetypes = {}
    endif
    if !exists('b:mkd_included_filetypes')
        " set syntax file name included
        let b:mkd_included_filetypes = {}
    endif
    if !a:force && (b:mkd_known_filetypes == filetypes || empty(filetypes))
        return
    endif

    " Now we're ready to actually highlight the code blocks.
    let startgroup = 'mkdCodeStart'
    let endgroup = 'mkdCodeEnd'
    for ft in keys(filetypes)
        if a:force || !has_key(b:mkd_known_filetypes, ft)
            if has_key(s:filetype_dict, ft)
                let filetype = s:filetype_dict[ft]
            else
                let filetype = ft
            endif
            let group = 'mkdSnippet' . toupper(substitute(filetype, '[+-]', '_', 'g'))
            if !has_key(b:mkd_included_filetypes, filetype)
                let include = s:SyntaxInclude(filetype)
                let b:mkd_included_filetypes[filetype] = 1
            else
                let include = '@' . toupper(filetype)
            endif
            let command_backtick = 'syntax region %s matchgroup=%s start="^\s*`\{3,}\s*%s.*$" matchgroup=%s end="\s*`\{3,}$" keepend contains=%s'
            let command_tilde    = 'syntax region %s matchgroup=%s start="^\s*\~\{3,}\s*%s.*$" matchgroup=%s end="\s*\~\{3,}$" keepend contains=%s'
            execute printf(command_backtick, group, startgroup, ft, endgroup, include)
            execute printf(command_tilde,    group, startgroup, ft, endgroup, include)
            execute printf('syntax cluster mkdNonListItem add=%s', group)

            let b:mkd_known_filetypes[ft] = 1
        endif
    endfor
endfunction

function! s:SyntaxInclude(filetype)
    " Include the syntax highlighting of another {filetype}.
    let grouplistname = '@' . toupper(a:filetype)
    " Unset the name of the current syntax while including the other syntax
    " because some syntax scripts do nothing when "b:current_syntax" is set
    if exists('b:current_syntax')
        let syntax_save = b:current_syntax
        unlet b:current_syntax
    endif
    try
        execute 'syntax include' grouplistname 'syntax/' . a:filetype . '.vim'
        execute 'syntax include' grouplistname 'after/syntax/' . a:filetype . '.vim'
    catch /E484/
        " Ignore missing scripts
    endtry
    " Restore the name of the current syntax
    if exists('syntax_save')
        let b:current_syntax = syntax_save
    elseif exists('b:current_syntax')
        unlet b:current_syntax
    endif
    return grouplistname
endfunction

function! s:IsHighlightSourcesEnabledForBuffer()
    " Enable for markdown buffers, and for liquid buffers with markdown format
    return &filetype =~# 'aichat' || get(b:, 'liquid_subtype', '') =~# 'aichat'
endfunction

function! s:MarkdownRefreshSyntax(force)
    call s:MarkdownHighlightSources(a:force)
endfunction

function! s:MarkdownClearSyntaxVariables()
    if s:IsHighlightSourcesEnabledForBuffer()
        unlet! b:mkd_included_filetypes
    endif
endfunction

" These autocmd calling s:MarkdownRefreshSyntax need to be kept in sync with
" the autocmds calling s:MarkdownSetupFolding in after/ftplugin/markdown.vim.
autocmd! * <buffer>
autocmd BufWinEnter <buffer> call s:MarkdownRefreshSyntax(1)
autocmd BufUnload <buffer> call s:MarkdownClearSyntaxVariables()
autocmd BufWritePost <buffer> call s:MarkdownRefreshSyntax(0)
autocmd InsertEnter,InsertLeave <buffer> call s:MarkdownRefreshSyntax(0)
autocmd CursorHold,CursorHoldI <buffer> call s:MarkdownRefreshSyntax(0)