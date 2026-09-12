-- Core options
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Appearance
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
-- Unlike the global tabline, winbar renders a clickable buffer strip in each
-- split and highlights the buffer displayed in that particular window.
opt.winbar = "%!v:lua.require'winbar'.render()"

vim.api.nvim_create_autocmd("FileType", {
    pattern = "NvimTree",
    callback = function()
        vim.opt_local.winbar = ""
    end,
})

-- Behavior
opt.splitright = true
opt.splitbelow = true
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 300
opt.clipboard = "unnamedplus"
opt.mouse = "a"

-- Completion (native 0.12)
opt.completeopt = { "menu", "menuone", "noselect" }

-- Folding (treesitter)
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = ""
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.fillchars:append { fold = " " }

-- Disable netrw (using telescope file browser)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
