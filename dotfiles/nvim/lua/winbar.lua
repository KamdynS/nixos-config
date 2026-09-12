-- A window-local buffer bar. Neovim's tabline is global, while winbar is
-- rendered once per split, so each window can highlight its own active buffer.
local M = {}

function M.setup_highlights()
    -- Link to standard groups so this stays readable across every rice theme.
    vim.api.nvim_set_hl(0, "NvimWinbarSelected", { link = "PmenuSel" })
    vim.api.nvim_set_hl(0, "NvimWinbarVisible", { link = "TabLineSel" })
    vim.api.nvim_set_hl(0, "NvimWinbarHidden", { link = "TabLine" })
    vim.api.nvim_set_hl(0, "NvimWinbarFill", { link = "TabLineFill" })
end

local function listed_buffers()
    local buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
            table.insert(buffers, buf)
        end
    end
    return buffers
end

local function display_name(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then
        return "[No Name]"
    end
    -- Escape statusline control characters in filenames.
    return vim.fn.fnamemodify(name, ":t"):gsub("%%", "%%%%")
end

function M.render()
    local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(win) then
        return ""
    end

    local current = vim.api.nvim_win_get_buf(win)
    local focused = win == vim.api.nvim_get_current_win()
    local buffers = listed_buffers()
    local tabs = {}

    for index, buf in ipairs(buffers) do
        local highlight = "%#NvimWinbarHidden#"
        local marker = ""
        if buf == current then
            highlight = focused and "%#NvimWinbarSelected#" or "%#NvimWinbarVisible#"
            marker = focused and "▸ " or ""
        end
        local modified = vim.bo[buf].modified and " ●" or ""
        local separator = index < #buffers and " │" or ""
        tabs[#tabs + 1] = string.format(
            "%s%%%d@v:lua.NvimWinbarBufferClick@ %s%s%s %s%%X",
            highlight,
            index,
            marker,
            display_name(buf),
            modified,
            separator
        )
    end

    return table.concat(tabs) .. "%#NvimWinbarFill#%="
end

function _G.NvimWinbarBufferClick(index, _, button, _)
    if button ~= "l" then
        return
    end

    local buf = listed_buffers()[index]
    local win = vim.fn.getmousepos().winid
    if buf and win > 0 and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_set_current_win(win)
        vim.api.nvim_win_set_buf(win, buf)
    end
end

M.setup_highlights()

return M
