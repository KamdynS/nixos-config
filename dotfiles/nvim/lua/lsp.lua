-- Native LSP configuration (Neovim 0.12+)
-- LSPs are installed via Nix, not Mason

-- Diagnostic config
vim.diagnostic.config {
    virtual_lines = { current_line = true }, -- multi-line, wrapped, only on cursor line
    virtual_text = false,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = { border = "rounded" },
}

-- LSP server configs
vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
        },
    },
})

vim.lsp.config("rust_analyzer", {
    settings = {
        ["rust-analyzer"] = {
            check = { command = "clippy" },
            inlayHints = {
                chainingHints = { enable = true },
                parameterHints = { enable = true },
                typeHints = { enable = true },
            },
        },
    },
})

vim.lsp.config("gopls", {
    settings = {
        gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
            hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                compositeLiteralTypes = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
            },
        },
    },
})

local ts_inlay = {
    includeInlayParameterNameHints = "all",
    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
    includeInlayFunctionParameterTypeHints = true,
    includeInlayVariableTypeHints = true,
    includeInlayPropertyDeclarationTypeHints = true,
    includeInlayFunctionLikeReturnTypeHints = true,
    includeInlayEnumMemberValueHints = true,
}

vim.lsp.config("ts_ls", {
    settings = {
        typescript = { inlayHints = ts_inlay },
        javascript = { inlayHints = ts_inlay },
    },
})

-- Enable LSP servers (installed via Nix)
vim.lsp.enable {
    "lua_ls",
    "rust_analyzer",
    "gopls",
    "pyright",
    "ts_ls",
    "html",
    "cssls",
    "clangd",
    "nil_ls", -- Nix
}

-- On attach: keymaps + inlay hints + native completion
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local bufnr = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        -- Enable inlay hints
        if client and client:supports_method "textDocument/inlayHint" then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end

        -- Completion handled by blink.cmp (see plugins/init.lua)

        -- LSP keymaps
        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map("n", "gd", function()
            require("telescope.builtin").lsp_definitions()
        end, "Go to definition")
        map("n", "gr", function()
            require("telescope.builtin").lsp_references()
        end, "Find references")
        map("n", "gi", function()
            require("telescope.builtin").lsp_implementations()
        end, "Go to implementation")
        map("n", "gD", function()
            require("telescope.builtin").lsp_type_definitions()
        end, "Type definition")
        map("n", "K", vim.lsp.buf.hover, "Hover docs")
        map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
        map("n", "<leader>f", function()
            vim.lsp.buf.format { async = true }
        end, "Format buffer")
        map("n", "<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
        end, "Toggle inlay hints")
    end,
})
