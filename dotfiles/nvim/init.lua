-- Minimal Neovim 0.12 config
-- Uses native LSP, native completion, lazy.nvim for plugins

-- Leader key (before lazy)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable netrw (nvim-tree replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system {
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    }
end
vim.opt.rtp:prepend(lazypath)

-- Load config modules
require "options"
require "keymaps"
require "lsp"
require("lazy").setup("plugins", {
    change_detection = { notify = false },
})

-- Theme application: read ~/.config/nvim-theme/active.lua and apply colorscheme.
-- Themes with a dedicated nvim plugin use it; the rest are rendered from the
-- base16 palette in active.lua via lua/base16.lua.
local theme_map = {
    ["gruvbox-light"] = { scheme = "gruvbox", bg = "light" },
    ["gruvbox-dark"] = { scheme = "gruvbox", bg = "dark" },
    ["catppuccin-mocha"] = { scheme = "catppuccin-mocha", bg = "dark" },
    ["catppuccin-latte"] = { scheme = "catppuccin-latte", bg = "light" },
    ["kanagawa"] = { scheme = "kanagawa", bg = "dark" },
    ["rose-pine"] = { scheme = "rose-pine", bg = "dark" },
    ["tokyonight"] = { scheme = "tokyonight", bg = "dark" },
}

local function refresh_winbar_highlights()
    local ok, winbar = pcall(require, "winbar")
    if ok then
        winbar.setup_highlights()
    end
end

local function apply_theme()
    local theme_file = vim.fn.expand "~/.config/nvim-theme/active.lua"
    if not vim.uv.fs_stat(theme_file) then
        return
    end
    -- dofile caches; clear so we always read fresh contents after a symlink swap
    package.loaded[theme_file] = nil
    local ok, theme = pcall(dofile, theme_file)
    if not ok or type(theme) ~= "table" or not theme.name then
        return
    end

    local t = theme_map[theme.name]
    if t then
        vim.opt.background = t.bg
        pcall(vim.cmd.colorscheme, t.scheme)
        refresh_winbar_highlights()
        return
    end

    -- Fallback: render directly from the palette
    if type(theme.palette) ~= "table" then
        return
    end
    package.loaded["base16"] = nil
    local ok_b16, base16 = pcall(require, "base16")
    if ok_b16 then
        pcall(base16.apply, theme)
    end
    refresh_winbar_highlights()
end

apply_theme()

-- Watch nvim-theme directory; re-apply when active.lua changes
local watcher = vim.uv.new_fs_event()
if watcher then
    local watch_dir = vim.fn.expand "~/.config/nvim-theme"
    watcher:start(
        watch_dir,
        {},
        vim.schedule_wrap(function(err, filename)
            if err or filename ~= "active.lua" then
                return
            end
            apply_theme()
        end)
    )
end
