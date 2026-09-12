-- Keymaps
local map = vim.keymap.set

-- Better command mode
map("n", ";", ":", { desc = "Command mode" })
map("i", "jk", "<ESC>", { desc = "Exit insert mode" })

-- Centered navigation
map("n", "n", "nzz", { desc = "Next search (centered)" })
map("n", "N", "Nzz", { desc = "Prev search (centered)" })
map("n", "*", "*zz", { desc = "Search word forward" })
map("n", "#", "#zz", { desc = "Search word backward" })
map("n", "<C-d>", "<C-d>zz", { desc = "Page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Page up (centered)" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Move the current buffer into a new split, leaving another buffer behind in
-- the original window. Native <C-w>v/<C-w>s remain available when a duplicate
-- view of the same buffer is wanted instead.
local function move_buffer_to_split(command)
    local source_win = vim.api.nvim_get_current_win()
    local moving_buf = vim.api.nvim_get_current_buf()
    local replacement = vim.fn.bufnr "#"

    if replacement < 0
        or replacement == moving_buf
        or not vim.api.nvim_buf_is_valid(replacement)
        or not vim.bo[replacement].buflisted
    then
        replacement = nil
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if buf ~= moving_buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
                replacement = buf
                break
            end
        end
    end

    replacement = replacement or vim.api.nvim_create_buf(true, false)
    vim.cmd(command)
    vim.api.nvim_win_set_buf(source_win, replacement)
end

map("n", "<leader>wv", function()
    move_buffer_to_split "vsplit"
end, { desc = "Move buffer to vertical split" })
map("n", "<leader>wh", function()
    move_buffer_to_split "split"
end, { desc = "Move buffer to horizontal split" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Close current buffer without nuking the window layout.
-- Switches every window showing this buffer to another listed buffer first,
-- so nvim-tree (or any other sidebar) doesn't collapse or get covered.
local function close_buffer()
    local cur = vim.api.nvim_get_current_buf()
    local alt = vim.tbl_filter(function(b)
        return vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and b ~= cur
    end, vim.api.nvim_list_bufs())

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == cur then
            if #alt > 0 then
                vim.api.nvim_win_set_buf(win, alt[1])
            else
                vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
            end
        end
    end
    pcall(vim.cmd, "bdelete " .. cur)
end
map("n", "<leader>x", close_buffer, { desc = "Close buffer (keep layout)" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search" })

-- LSP keymaps (set in lsp.lua on attach)

-- Diagnostic navigation
map("n", "[d", function()
    vim.diagnostic.goto_prev()
    vim.cmd "normal! zz"
end, { desc = "Prev diagnostic" })
map("n", "]d", function()
    vim.diagnostic.goto_next()
    vim.cmd "normal! zz"
end, { desc = "Next diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnostic float" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostic list" })
