if status is-interactive
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    if not set -q BROWSER
        set -gx BROWSER librewolf
    end
    set -g fish_greeting 'Welcome to Kova Linux 🦀  |  edit: nvim'
    if type -q zoxide
        zoxide init fish | source
    end
end
