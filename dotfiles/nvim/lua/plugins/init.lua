-- Plugins (lazy.nvim)
return {
    -- Treesitter (syntax highlighting) - main branch, compatible with nvim 0.12
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").install {
                "lua",
                "vim",
                "vimdoc",
                "query",
                "rust",
                "go",
                "python",
                "javascript",
                "typescript",
                "tsx",
                "html",
                "css",
                "json",
                "yaml",
                "toml",
                "c",
                "cpp",
                "nix",
                "bash",
                "markdown",
                "markdown_inline",
            }

            -- Enable highlighting per buffer when filetype is detected
            vim.api.nvim_create_autocmd("FileType", {
                callback = function(args)
                    pcall(vim.treesitter.start, args.buf)
                end,
            })
        end,
    },

    -- Telescope (fuzzy finder)
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "Telescope",
        keys = {
            { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
            { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
            { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
            { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
            { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
            { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Search buffer" },
        },
        opts = {
            defaults = {
                file_ignore_patterns = { "node_modules", ".git/" },
                layout_strategy = "horizontal",
                sorting_strategy = "ascending",
                layout_config = { prompt_position = "top" },
            },
        },
    },

    -- Gitsigns (git integration)
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add = { text = "│" },
                change = { text = "│" },
                delete = { text = "_" },
                topdelete = { text = "‾" },
                changedelete = { text = "~" },
            },
            on_attach = function(bufnr)
                local gs = require "gitsigns"
                local map = function(mode, l, r, desc)
                    vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
                end
                map("n", "]c", function()
                    gs.nav_hunk "next"
                    vim.cmd "normal! zz"
                end, "Next hunk")
                map("n", "[c", function()
                    gs.nav_hunk "prev"
                    vim.cmd "normal! zz"
                end, "Prev hunk")
                map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
                map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
                map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
                map("n", "<leader>hb", gs.blame_line, "Blame line")
            end,
        },
    },

    -- Conform (formatting)
    {
        "stevearc/conform.nvim",
        event = "BufWritePre",
        cmd = "ConformInfo",
        keys = {
            {
                "<leader>cf",
                function()
                    require("conform").format { async = true }
                end,
                desc = "Format",
            },
        },
        opts = {
            formatters_by_ft = {
                lua = { "stylua" },
                rust = { "rustfmt" },
                go = { "gofmt" },
                python = { "black" },
                javascript = { "prettierd" },
                typescript = { "prettierd" },
                javascriptreact = { "prettierd" },
                typescriptreact = { "prettierd" },
                html = { "prettierd" },
                css = { "prettierd" },
                json = { "prettierd" },
                yaml = { "prettierd" },
                markdown = { "prettierd" },
                nix = { "nixfmt" },
            },
            format_on_save = { timeout_ms = 500, lsp_fallback = true },
        },
    },

    -- Trouble (diagnostics list)
    {
        "folke/trouble.nvim",
        cmd = "Trouble",
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
            { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
        },
        opts = {},
    },

    -- Which-key (keybind hints)
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            delay = 300,
            icons = { mappings = false },
        },
        config = function(_, opts)
            local wk = require "which-key"
            wk.setup(opts)
            wk.add {
                { "<leader>f", group = "find" },
                { "<leader>h", group = "git hunk" },
                { "<leader>c", group = "code" },
                { "<leader>w", group = "window" },
                { "<leader>x", group = "diagnostics" },
            }
        end,
    },

    -- Lazygit
    {
        "kdheepak/lazygit.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "LazyGit",
        keys = {
            { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
        },
    },

    -- Autopairs
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = { check_ts = true },
    },

    -- LSP defaults (cmd, filetypes, root_markers for all common LSPs)
    -- Required for vim.lsp.enable() to actually start the servers
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        priority = 900,
    },

    -- Completion (blink.cmp - fast, native LSP integration)
    {
        "saghen/blink.cmp",
        version = "*",
        event = "InsertEnter",
        opts = {
            keymap = {
                preset = "default",
                ["<Tab>"] = { "select_next", "fallback" },
                ["<S-Tab>"] = { "select_prev", "fallback" },
            },
            appearance = {
                nerd_font_variant = "mono",
                use_nvim_cmp_as_default = false,
            },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
            },
            completion = {
                accept = { auto_brackets = { enabled = true } },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 200,
                    window = { border = "rounded", max_width = 80 },
                },
                ghost_text = { enabled = true },
                list = { selection = { preselect = false, auto_insert = true } },
                menu = {
                    border = "rounded",
                    draw = {
                        columns = {
                            { "kind_icon", "label", "label_description", gap = 1 },
                            { "kind", "source_name" },
                        },
                        treesitter = { "lsp" },
                    },
                },
            },
            signature = { enabled = true, window = { border = "rounded" } },
        },
    },

    -- File explorer (nvim-tree, NvChad-style sidebar)
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        lazy = false,
        keys = {
            {
                "<leader>e",
                function()
                    local view = require "nvim-tree.view"
                    local api = require "nvim-tree.api"
                    if not view.is_visible() then
                        api.tree.open()
                    elseif vim.bo.filetype == "NvimTree" then
                        vim.cmd "wincmd p"
                    else
                        api.tree.focus()
                    end
                end,
                desc = "Tree: focus / jump back",
            },
            { "<leader>E", "<cmd>NvimTreeClose<cr>", desc = "Tree: close" },
            { "<leader>fe", "<cmd>NvimTreeFindFile<cr>", desc = "Tree: reveal current file" },
        },
        opts = {
            hijack_directories = { enable = true, auto_open = true },
            update_focused_file = { enable = true },
            view = { width = 32, side = "left", signcolumn = "no" },
            renderer = {
                group_empty = true,
                indent_markers = { enable = true },
                icons = { show = { folder_arrow = false } },
            },
            filters = { dotfiles = false, git_ignored = false },
            git = { enable = true },
            diagnostics = { enable = true },
            actions = { open_file = { quit_on_open = false } },
        },
    },

    -- Statusline (mini.statusline - lightweight)
    {
        "echasnovski/mini.statusline",
        event = "VeryLazy",
        opts = { use_icons = true },
    },

    -- Bufferline (NvChad-style tab bar for open buffers)
    {
        "akinsho/bufferline.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        keys = {
            { "<Tab>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
            { "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
        },
        opts = {
            options = {
                mode = "buffers",
                separator_style = "slant",
                diagnostics = "nvim_lsp",
                show_buffer_close_icons = true,
                show_close_icon = false,
                always_show_bufferline = true,
                offsets = {
                    {
                        filetype = "NvimTree",
                        text = "File Explorer",
                        text_align = "left",
                        separator = true,
                    },
                },
            },
        },
    },

    -- Discord Rich Presence
    {
        "vyfor/cord.nvim",
        build = ":Cord update",
        opts = {},
    },

    -- Colorschemes for the rice's 6 themes
    { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000 },
    { "catppuccin/nvim", lazy = false, priority = 1000, name = "catppuccin" },
    { "rebelot/kanagawa.nvim", lazy = false, priority = 1000 },
    { "rose-pine/neovim", lazy = false, priority = 1000, name = "rose-pine" },
    { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
}
