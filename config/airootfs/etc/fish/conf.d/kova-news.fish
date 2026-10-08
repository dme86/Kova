# Reading a cached local file is instant; systemd fetches news in the background.
if status is-interactive
    if command -sq kova
        kova news --summary
    end
end
