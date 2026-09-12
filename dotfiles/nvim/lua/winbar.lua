-- A window-local buffer bar. Neovim's tabline is global, while winbar is
-- rendered once per split, so each window can highlight its own active buffer.
local M = {}

function M.setup_highlights()
    -- Link to standard groups so this stays readable across every rice theme.
    vim.api.nvim_set_hl(0, "NvimWinbarSelected", { link = "PmenuSel" })
    vim.api.nvim_set_hl(0, "NvimWinbarVisible", { link = "TabLineSel" })
    vim.api.nvim_set_hl(0, "NvimWinbarHidden", { link = "TabLine" })
    vim.api.nvim_set_hl(0, "NvimWinbarFill", { link = "TabLineFill" })
    vim.api.nvim_set_hl(0, "NvimTreeWindowPicker", { link = "PmenuSel" })
end

local function is_listed(buf)
    return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
end

local function set_window_buffers(win, buffers)
    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_var(win, "winbar_buffers", buffers)
    end
end

local function window_buffers(win)
    if not vim.api.nvim_win_is_valid(win) then
        return {}
    end

    local ok, saved = pcall(vim.api.nvim_win_get_var, win, "winbar_buffers")
    local buffers = {}
    local seen = {}
    if ok and type(saved) == "table" then
        for _, buf in ipairs(saved) do
            if is_listed(buf) and not seen[buf] then
                buffers[#buffers + 1] = buf
                seen[buf] = true
            end
        end
    end

    local current = vim.api.nvim_win_get_buf(win)
    if is_listed(current) and not seen[current] then
        buffers[#buffers + 1] = current
    end
    set_window_buffers(win, buffers)
    return buffers
end

function M.add_buffer(win, buf)
    local buffers = window_buffers(win)
    if is_listed(buf) and not vim.tbl_contains(buffers, buf) then
        buffers[#buffers + 1] = buf
        set_window_buffers(win, buffers)
    end
end

function M.move_buffer(source_win, destination_win, moving_buf, replacement)
    local source_buffers = vim.tbl_filter(function(buf)
        return buf ~= moving_buf
    end, window_buffers(source_win))
    if is_listed(replacement) and not vim.tbl_contains(source_buffers, replacement) then
        source_buffers[#source_buffers + 1] = replacement
    end

    set_window_buffers(source_win, source_buffers)
    set_window_buffers(destination_win, { moving_buf })
end

function M.cycle(direction)
    local win = vim.api.nvim_get_current_win()
    local buffers = window_buffers(win)
    if #buffers < 2 then
        return
    end

    local current = vim.api.nvim_win_get_buf(win)
    local index = vim.fn.index(buffers, current) + 1
    if index < 1 then
        index = 1
    end
    local target = ((index - 1 + direction) % #buffers) + 1
    vim.api.nvim_win_set_buf(win, buffers[target])
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
    local buffers = window_buffers(win)
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

    local win = vim.fn.getmousepos().winid
    local buf = win > 0 and window_buffers(win)[index] or nil
    if buf and win > 0 and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_set_current_win(win)
        vim.api.nvim_win_set_buf(win, buf)
    end
end

M.setup_highlights()

local group = vim.api.nvim_create_augroup("WindowLocalBufferTabs", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
        if vim.bo[args.buf].filetype ~= "NvimTree" then
            M.add_buffer(vim.api.nvim_get_current_win(), args.buf)
        end
    end,
})
vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buffers = vim.tbl_filter(function(buf)
                return buf ~= args.buf
            end, window_buffers(win))
            set_window_buffers(win, buffers)
        end
    end,
})

return M
