if status is-interactive
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -g fish_greeting 'Welcome to Kova Linux 🦀  |  edit: nvim'
    if type -q zoxide
        zoxide init fish | source
    end
end
