# Rust-first interactive command defaults.
# Keep the underlying GNU tools intact for scripts and package management.
if status is-interactive
    if type -q eza
        alias ls 'eza --group-directories-first'
        alias ll 'eza -lah --git'
        alias la 'eza -a'
    end

    if type -q bat
        alias cat 'bat --paging=never --style=plain'
    end

    if type -q uu-cp
        alias cp uu-cp
    end
    if type -q uu-mv
        alias mv uu-mv
    end
    if type -q uu-rm
        alias rm uu-rm
    end
    if type -q uu-mkdir
        alias mkdir uu-mkdir
    end
    if type -q uu-touch
        alias touch uu-touch
    end
    if type -q uu-sort
        alias sort uu-sort
    end
    if type -q uu-wc
        alias wc uu-wc
    end

    # Modern Rust UIs; use dust/procs/dysk syntax rather than GNU options.
    if type -q dust
        alias du dust
    end
    if type -q procs
        alias ps procs
    end
    if type -q dysk
        alias df dysk
    end
end
