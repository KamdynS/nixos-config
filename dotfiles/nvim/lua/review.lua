-- Line-anchored review comments, batched and handed to Claude Code.
--
-- Comments live only in this Neovim instance (they die with it). Sending
-- writes the batch to a queue file; the UserPromptSubmit hook
-- (dotfiles/claude/hooks/nvim-review.sh) attaches it to the next prompt you
-- submit in any Claude Code session, then deletes it.

local M = {}

M.queue_file = vim.fn.expand "~/.local/state/nvim-review/pending.md"

local ns = vim.api.nvim_create_namespace "review"
local comments = {} -- { buf, mark, text }

local function hl()
    vim.api.nvim_set_hl(0, "ReviewComment", { link = "DiagnosticVirtualTextInfo", default = true })
    vim.api.nvim_set_hl(0, "ReviewSign", { link = "DiagnosticSignInfo", default = true })
end

-- Current (1-based) line range of a comment; extmarks follow edits.
local function range(c)
    local m = vim.api.nvim_buf_get_extmark_by_id(c.buf, ns, c.mark, { details = true })
    if not m[1] then
        return nil
    end
    local s = m[1] + 1
    local e = (m[3] and m[3].end_row or m[1]) + 1
    return s, e
end

-- Path relative to the git root (what Claude's cwd usually is), else ~-path.
local function display_path(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    local root = vim.fs.root(file, ".git")
    if root then
        return file:sub(#root + 2)
    end
    return vim.fn.fnamemodify(file, ":~")
end

local function label(c)
    local s, e = range(c)
    if not s then
        return nil
    end
    local lines = s == e and tostring(s) or (s .. "," .. e)
    return display_path(c.buf) .. ":" .. lines
end

local function live()
    local out = {}
    for _, c in ipairs(comments) do
        if vim.api.nvim_buf_is_valid(c.buf) and range(c) then
            table.insert(out, c)
        end
    end
    table.sort(out, function(a, b)
        local pa, pb = display_path(a.buf), display_path(b.buf)
        if pa ~= pb then
            return pa < pb
        end
        return (range(a)) < (range(b))
    end)
    comments = out
    return out
end

local function place(c, s, e)
    c.mark = vim.api.nvim_buf_set_extmark(c.buf, ns, s - 1, 0, {
        id = c.mark,
        end_row = e - 1,
        virt_text = { { "  " .. c.text, "ReviewComment" } },
        virt_text_pos = "eol",
        sign_text = "",
        sign_hl_group = "ReviewSign",
    })
end

function M.add(s, e)
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_name(buf) == "" then
        return vim.notify("review: buffer has no file", vim.log.levels.WARN)
    end
    vim.ui.input({ prompt = s == e and ("Comment L" .. s .. ": ") or ("Comment L" .. s .. "," .. e .. ": ") }, function(text)
        if not text or vim.trim(text) == "" then
            return
        end
        local c = { buf = buf, text = vim.trim(text) }
        place(c, s, e)
        table.insert(comments, c)
    end)
end

-- Comment(s) touching the cursor line in the current buffer.
local function at_cursor()
    local buf = vim.api.nvim_get_current_buf()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local hits = {}
    for i, c in ipairs(live()) do
        local s, e = range(c)
        if c.buf == buf and lnum >= s and lnum <= e then
            table.insert(hits, i)
        end
    end
    return hits
end

function M.delete()
    local hits = at_cursor()
    for k = #hits, 1, -1 do
        local c = table.remove(comments, hits[k])
        vim.api.nvim_buf_del_extmark(c.buf, ns, c.mark)
    end
    if #hits == 0 then
        vim.notify "review: no comment on this line"
    end
end

function M.edit()
    local hits = at_cursor()
    if #hits == 0 then
        return vim.notify "review: no comment on this line"
    end
    local c = comments[hits[1]]
    vim.ui.input({ prompt = "Comment: ", default = c.text }, function(text)
        if not text then
            return
        end
        if vim.trim(text) == "" then
            vim.api.nvim_buf_del_extmark(c.buf, ns, c.mark)
            table.remove(comments, hits[1])
            return
        end
        c.text = vim.trim(text)
        place(c, range(c))
    end)
end

function M.clear()
    for _, c in ipairs(comments) do
        if vim.api.nvim_buf_is_valid(c.buf) then
            vim.api.nvim_buf_del_extmark(c.buf, ns, c.mark)
        end
    end
    comments = {}
end

function M.list()
    local items = {}
    for _, c in ipairs(live()) do
        local s, e = range(c)
        table.insert(items, { bufnr = c.buf, lnum = s, end_lnum = e, text = c.text })
    end
    if #items == 0 then
        return vim.notify "review: no comments"
    end
    vim.fn.setqflist({}, " ", { title = "Review comments", items = items })
    vim.cmd "copen"
end

local function render()
    local lines = {}
    for _, c in ipairs(live()) do
        table.insert(lines, string.format('%s: "%s"', label(c), c.text))
    end
    return lines
end

-- Open a scratch buffer: prompt on top, comments below. :w queues it.
function M.send()
    local body = render()
    if #body == 0 then
        return vim.notify "review: no comments"
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "review://send")
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.list_extend({ "", "" }, body))
    vim.bo[buf].modified = false

    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
            if text == "" then
                return vim.notify("review: empty, nothing sent", vim.log.levels.WARN)
            end
            vim.fn.mkdir(vim.fn.fnamemodify(M.queue_file, ":h"), "p")
            local f = assert(io.open(M.queue_file, "a"))
            f:write(text, "\n\n")
            f:close()
            M.clear()
            vim.bo[buf].modified = false
            vim.cmd "bwipeout"
            vim.notify "review: queued — submit any prompt in Claude to deliver"
        end,
    })

    vim.cmd "botright split"
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_win_set_height(0, math.min(#body + 4, 20))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd "startinsert"
end

function M.setup()
    hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = hl })

    local map = vim.keymap.set
    map("n", "<leader>aa", function()
        local l = vim.api.nvim_win_get_cursor(0)[1]
        M.add(l, l)
    end, { desc = "Annotate line" })
    map("x", "<leader>aa", function()
        local s, e = vim.fn.line "v", vim.fn.line "."
        if s > e then
            s, e = e, s
        end
        vim.api.nvim_feedkeys(vim.keycode "<Esc>", "nx", false)
        M.add(s, e)
    end, { desc = "Annotate range" })
    map("n", "<leader>ae", M.edit, { desc = "Edit annotation" })
    map("n", "<leader>ad", M.delete, { desc = "Delete annotation" })
    map("n", "<leader>al", M.list, { desc = "List annotations" })
    map("n", "<leader>as", M.send, { desc = "Send annotations to Claude" })
    map("n", "<leader>aX", M.clear, { desc = "Clear all annotations" })
end

return M
