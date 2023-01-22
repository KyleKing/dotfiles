-- AstroNvim Configuration Table
-- All configuration changes should go inside of the table below

-- You can think of a Lua "table" as a dictionary like data structure the
-- normal format is "key = value". These also handle array like data structures
-- where a value with no key simply has an implicit numeric key
local config = {

	-- Configure AstroNvim updates
	updater = {
		remote = "origin", -- remote to use
		channel = "nightly", -- "stable" or "nightly"
		version = "latest", -- "latest", tag name, or regex search like "v1.*" to only do updates before v2 (STABLE ONLY)
		branch = "v3", -- branch name (NIGHTLY ONLY)
		commit = nil, -- commit hash (NIGHTLY ONLY)
		pin_plugins = nil, -- nil, true, false (nil will pin plugins on stable only)
		skip_prompts = false, -- skip prompts about breaking changes
		show_changelog = true, -- show the changelog after performing an update
		auto_quit = true, -- automatically quit the current session after a successful update
		-- remotes = { -- easily add new remotes to track
		--   ["remote_name"] = "https://remote_url.come/repo.git", -- full remote url
		--   ["remote2"] = "github_user/repo", -- GitHub user/repo shortcut,
		--   ["remote3"] = "github_user", -- GitHub user assume AstroNvim fork
		-- },
	},

	-- Set colorscheme to use
	-- colorscheme = "astronvim",
	colorscheme = "nightfox",

	-- Add highlight groups in any theme
	highlights = {
		-- init = { -- this table overrides highlights in all themes
		--   Normal = { bg = "#000000" },
		-- }
		-- duskfox = { -- a table of overrides/changes to the duskfox theme
		--   Normal = { bg = "#000000" },
		-- },
	},

	-- set vim options here (vim.<first_key>.<second_key> = value)
	options = {
		opt = {
			relativenumber = true, -- sets vim.opt.relativenumber
			number = true, -- sets vim.opt.number
			spell = false, -- sets vim.opt.spell
			signcolumn = "auto", -- sets vim.opt.signcolumn to auto
			wrap = false, -- sets vim.opt.wrap
			colorcolumn = "80,120",
		},
		g = {
			mapleader = " ", -- sets vim.g.mapleader
			autoformat_enabled = false, -- enable or disable auto formatting at start (lsp.formatting.format_on_save must be enabled)
			cmp_enabled = true, -- enable completion at start
			autopairs_enabled = true, -- enable autopairs at start
			diagnostics_enabled = true, -- enable diagnostics at start
			status_diagnostics_enabled = true, -- enable diagnostics in statusline
			icons_enabled = true, -- disable icons in the UI (disable if no nerd font is available, requires :PackerSync after changing)
			ui_notifications_enabled = true, -- disable notifications when toggling UI elements
		},
	},
	-- If you need more control, you can use the function()...end notation
	-- options = function(local_vim)
	--   local_vim.opt.relativenumber = true
	--   local_vim.g.mapleader = " "
	--   local_vim.opt.whichwrap = vim.opt.whichwrap - { 'b', 's' } -- removing option from list
	--   local_vim.opt.shortmess = vim.opt.shortmess + { I = true } -- add to option list
	--
	--   return local_vim
	-- end,

	-- AstroNvim theme configuration
	astronvim_theme = {
		-- Modify the color palette for the default theme
		colors = {
			fg = "#abb2bf",
			bg = "#1e222a",
		},
		highlights = function(hl) -- or a function that returns a new table of colors to set
			local C = require("astronvim_theme.colors")

			hl.Normal = { fg = C.fg, bg = C.bg }

			-- New approach instead of diagnostic_style
			hl.DiagnosticError.italic = true
			hl.DiagnosticHint.italic = true
			hl.DiagnosticInfo.italic = true
			hl.DiagnosticWarn.italic = true

			return hl
		end,
		-- enable or disable highlighting for extra plugins
		plugins = {
			aerial = true,
			beacon = false,
			bufferline = false,
			cmp = true,
			dashboard = true,
			highlighturl = true,
			hop = false,
			indent_blankline = true,
			lightspeed = false,
			["neo-tree"] = true,
			notify = true,
			["nvim-tree"] = false,
			["nvim-web-devicons"] = true,
			rainbow = true,
			symbols_outline = false,
			telescope = true,
			treesitter = true,
			vimwiki = false,
			["which-key"] = true,
		},
	},

	-- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
	diagnostics = {
		virtual_text = true,
		underline = true,
	},

	-- Extend LSP configuration
	lsp = {
		-- enable servers that you already have installed without mason
		servers = {
			-- "pyright"
		},
		formatting = {
			-- control auto formatting on save
			format_on_save = {
				enabled = true, -- enable or disable format on save globally
				allow_filetypes = { -- enable format on save for specified filetypes only
					-- "go",
				},
				ignore_filetypes = { -- disable format on save for specified filetypes
					-- "python",
				},
			},
			disabled = { -- disable formatting capabilities for the listed language servers
				-- "sumneko_lua",
			},
			timeout_ms = 1000, -- default format timeout
			-- filter = function(client) -- fully override the default formatting function
			--   return true
			-- end
		},
		-- easily add or disable built in mappings added during LSP attaching
		mappings = {
			n = {
				-- ["<leader>lf"] = false -- disable formatting keymap
			},
		},
		-- add to the global LSP on_attach function
		-- on_attach = function(client, bufnr)
		-- end,

		-- override the LSP setup handler function based on server name
		-- setup_handlers = {
		--   -- first function changes the default setup handler
		--   function(server, opts) require("lspconfig")[server].setup(opts) end,
		--   -- keys for a specific server name will be used for that LSP
		--   sumneko_lua = function(server, opts)
		--     -- custom sumneko_lua setup handler
		--     require("lspconfig")["sumneko_lua"].setup(opts)
		--   end,
		-- },

		-- Add overrides for LSP server settings, the keys are the name of the server
		config = {
			-- example for addings schemas to yamlls
			-- yamlls = { -- override table for require("lspconfig").yamlls.setup({...})
			--   settings = {
			--     yaml = {
			--       schemas = {
			--         ["http://json.schemastore.org/github-workflow"] = ".github/workflows/*.{yml,yaml}",
			--         ["http://json.schemastore.org/github-action"] = ".github/action.{yml,yaml}",
			--         ["http://json.schemastore.org/ansible-stable-2.9"] = "roles/tasks/*.{yml,yaml}",
			--       },
			--     },
			--   },
			-- },
			python_lsp_server = {
				settings = {
					configurationSources = { "flake8" },
					-- formatCommand = { "black" },
					pylsp = {
						plugins = {
							autopep8 = { enabled = false },
							black = { enabled = true },
							flake8 = { enabled = false, ignore = { "E501" } },
							isort = { enabled = false }, -- FYI: Use isort from Packer instead
							mccabe = { enabled = false },
							pycodestyle = { enabled = false },
							pydocstyle = { enabled = false },
							pyflakes = { enabled = false },
							pylint = { enabled = false },
							pyls_flake8 = { enabled = false },
							pyls_mypy = { enabled = false },
							rope_autoimport = { enabled = true },
							rope_completion = { enabled = true },
							ruff = { enabled = false },
							yapf = { enabled = false },
						},
					},
				},
			},
		},
	},

	-- Mapping data with "desc" stored directly by vim.keymap.set().
	--
	-- Please use this mappings table to set keyboard mapping since this is the
	-- lower level configuration and more robust one. (which-key will
	-- automatically pick-up stored data by this setting.)
	mappings = {
		-- first key is the mode
		n = {
			-- FIXME: Add mappings for H/L to start and end of line (^$)
			-- second key is the lefthand side of the map
			-- mappings seen under group name "Buffer"
			["<leader>bb"] = { "<cmd>tabnew<cr>", desc = "New tab" },
			["<leader>bc"] = { "<cmd>BufferLinePickClose<cr>", desc = "Pick to close" },
			["<leader>bj"] = { "<cmd>BufferLinePick<cr>", desc = "Pick to jump" },
			["<leader>bt"] = { "<cmd>BufferLineSortByTabs<cr>", desc = "Sort by tabs" },
			-- tables with the `name` key will be registered with which-key if it's installed
			-- this is useful for naming menus
			["<leader>b"] = { name = "Buffers" },
			-- quick save
			-- ["<C-s>"] = { ":w!<cr>", desc = "Save File" },  -- change description but the same command
		},
		t = {
			-- setting a mapping to false will disable it
			-- ["<esc>"] = false,
		},
	},

	-- Configure require("lazy").setup() options
	lazy = {
		defaults = { lazy = true },
		performance = {
			rtp = {
				-- customize default disabled vim plugins
				disabled_plugins = {
					"tohtml",
					"gzip",
					"matchit",
					"zipPlugin",
					"netrwPlugin",
					"tarPlugin",
					"matchparen",
				},
			},
		},
	},

	-- Configure plugins
	plugins = {
		-- You can disable default plugins as follows:
		-- { "max397574/better-escape.nvim", enabled = false },
		--
		-- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
		-- {
		--   "L3MON4D3/LuaSnip",
		--   config = function(plugin, opts)
		--     plugin.default_config(opts) -- include the default astronvim config that calls the setup call
		--     -- add more custom luasnip configuration such as filetype extend or custom snippets
		--     local luasnip = require "luasnip"
		--     luasnip.filetype_extend("javascript", { "javascriptreact" })
		--   end,
		-- },
		-- {
		--   "windwp/nvim-autopairs",
		--   config = function(plugin, opts)
		--     plugin.default_config(opts) -- include the default astronvim config that calls the setup call
		--     -- add more custom autopairs configuration such as custom rules
		--     local npairs = require "nvim-autopairs"
		--     local Rule = require "nvim-autopairs.rule"
		--     local cond = require "nvim-autopairs.conds"
		--     npairs.add_rules(
		--       {
		--         Rule("$", "$", { "tex", "latex" })
		--           -- don't add a pair if the next character is %
		--           :with_pair(cond.not_after_regex "%%")
		--           -- don't add a pair if  the previous character is xxx
		--           :with_pair(
		--             cond.not_before_regex("xxx", 3)
		--           )
		--           -- don't move right when repeat character
		--           :with_move(cond.none())
		--           -- don't delete if the next character is xx
		--           :with_del(cond.not_after_regex "xx")
		--           -- disable adding a newline when you press <cr>
		--           :with_cr(cond.none()),
		--       },
		--       -- disable for .vim files, but it work for another filetypes
		--       Rule("a", "a", "-vim")
		--     )
		--   end,
		-- },
		-- By adding to the which-key config and using our helper function you can add more which-key registered bindings
		-- {
		--   "folke/which-key.nvim",
		--   config = function(plugin, opts)
		--     plugin.default_config(opts)
		--     -- Add bindings which show up as group name
		--     local wk = require "which-key"
		--     wk.register({
		--       b = { name = "Buffer" },
		--     }, { mode = "n", prefix = "<leader>" })
		--   end,
		-- },

		-- You can also add new plugins here as well:
		-- Add plugins, the lazy syntax
		-- "andweeb/presence.nvim",
		-- {
		--   "ray-x/lsp_signature.nvim",
		--   event = "BufRead",
		--   config = function()
		--     require("lsp_signature").setup()
		--   end,
		-- },

		-- Themes
		-- "dracula/vim",  -- dracula
		{
			"EdenEast/nightfox.nvim", -- nightfox, duskfox
			-- PLANNED: These settings weren't being recognized?
			opts = {
				dim_inactive = true,
				styles = {
					comments = "italic",
					keywords = "bold",
					types = "italic,bold",
				},
			},
		},
		-- "folke/tokyonight.nvim",  -- tokyonight-storm
		-- "joshdick/onedark.vim",  -- onedark
		-- "rebelot/kanagawa.nvim",  -- kanagawa
		-- "roflolilolmao/oceanic-next.nvim",  -- OceanicNext
		{
			"sainnhe/everforest", -- everforest
			-- PLANNED: Need to figure out how configuration works. No lua examples
			-- config = function()
			-- 	set background=dark
			-- 	let g:everforest_background = 'soft'
			-- end,
			-- 	background = "dark",
			-- 	everforest_background = "hard",
			-- 	everforest_enable_italic = 1,
			-- 	everforest_dim_inactive_windows = 1,
			-- 	everforest_sign_column_background = "grey",
			-- 	everforest_ui_contrast = "high",
			-- better_performance = 1,
		},
		-- "sickill/vim-monokai", -- monokai
		-- "sonph/onehalf", -- onehalfdark

		-- Additional plugins
		{
			"kylechui/nvim-surround",
			event = "BufRead",
		},
		{
			"sheerun/vim-polyglot",
			event = "UIEnter",
		},
		{
			"folke/todo-comments.nvim",
			requires = "nvim-lua/plenary.nvim",
			event = "BufReadPre",
			config = function()
				require("todo-comments").setup({})
			end,
		},
		{
			"ray-x/lsp_signature.nvim",
			event = "BufRead",
			config = function()
				require("lsp_signature").setup()
			end,
		},
		{
			"codota/tabnine-nvim",
			-- event = "BufRead",
			config = function()
				require("tabnine").setup({
					disable_auto_comment = true,
					accept_keymap = "<Tab>",
					debounce_ms = 300,
					suggestion_color = { gui = "#808080", cterm = 244 },
				})
			end,
		},

		-- Plugin entries can also be used to override the default options for plugins as well
		{
			"goolord/alpha-nvim",
			opts = function(_, opts)
				-- customize the dashboard header
				opts.section.header.val = {
					-- " █████  ███████ ████████ ██████   ██████",
					-- "██   ██ ██         ██    ██   ██ ██    ██",
					-- "███████ ███████    ██    ██████  ██    ██",
					-- "██   ██      ██    ██    ██   ██ ██    ██",
					-- "██   ██ ███████    ██    ██   ██  ██████",
					" ",
					" ███    ██ ██    ██ ██ ███    ███",
					" ████   ██ ██    ██ ██ ████  ████",
					" ██ ██  ██ ██    ██ ██ ██ ████ ██",
					" ██  ██ ██  ██  ██  ██ ██  ██  ██",
					" ██   ████   ████   ██ ██      ██",
				}
				return opts
			end,
		},
		{
			"nvim-neo-tree/neo-tree.nvim",
			opts = {
				filesystem = {
					filtered_items = {
						hide_gitignored = true,
						hide_dotfiles = false,
					},
				},
			},
		},
		{
			"jose-elias-alvarez/null-ls.nvim",
			opts = function(_, config)
				-- config variable is the default configuration table for the setup function call
				local null_ls = require("null-ls")
				null_ls.setup({ debug = true })

				-- Check supported formatters and linters
				-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
				-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
				config.sources = {
					--
					-- Formatting
					null_ls.builtins.formatting.stylua,
					-- null_ls.builtins.formatting.prettier.with({
					--     prefer_local = "node_modules/.bin",
					-- }),
					-- null_ls.builtins.formatting.eslint.with({
					--     prefer_local = "node_modules/.bin",
					-- }),
					null_ls.builtins.formatting.taplo,
					null_ls.builtins.formatting.terraform_fmt,
					null_ls.builtins.formatting.trim_newlines,
					null_ls.builtins.formatting.trim_whitespace,
					--
					-- Diagnostics
					null_ls.builtins.diagnostics.eslint.with({
						prefer_local = "node_modules/.bin",
					}),
					-- FIXME: How are project configuration files recognized?
					null_ls.builtins.diagnostics.flake8.with({
						only_local = true,
					}),
					-- null_ls.builtins.diagnostics.pylint.with({
					-- 	only_local = true,
					-- }),
					-- null_ls.builtins.diagnostics.mypy.with({
					-- 	only_local = true,
					-- }),
					null_ls.builtins.diagnostics.shellcheck,
					null_ls.builtins.diagnostics.hadolint,
					--
					-- Code Actions
					null_ls.builtins.code_actions.gitsigns,
				}
				return config -- return final config table
			end,
		},
		{
			"nvim-treesitter/nvim-treesitter",
			opts = {
				-- ensure_installed = { "lua" },
				ensure_installed = { "lua", "python", "javascript", "html", "css", "json", "toml" },
			},
		},
		-- use mason-lspconfig to configure LSP installations
		{
			"williamboman/mason-lspconfig.nvim",
			-- overrides `require("mason-lspconfig").setup(...)`
			opts = {
				-- ensure_installed = { "sumneko_lua" },
				ensure_installed = {
					-- LSP
					"awk_ls",
					"bashls",
					-- "codeqlls",
					"dockerls",
					"eslint",
					"sumneko_lua",
					-- "pyright", -- Too much noise
					"pylsp",
					"sourcery",
					"taplo",
					"terraformls",
					"tflint",
					-- "yamlls",  -- Use prettier instead
				},
			},
		},
		-- use mason-null-ls to configure Formatters/Linter installation for null-ls sources
		{
			"jay-babu/mason-null-ls.nvim",
			-- overrides `require("mason-null-ls").setup(...)`
			opts = {
				-- ensure_installed = { "prettier", "stylua" },
				ensure_installed = {
					-- Examples: "prettier", "stylua",
					-- Diagnostics
					"actionlint",
					"codespell",
					"flake8",
					"jsonlint",
					"luacheck",
					"markdownlint",
					"proselint",
					"shellcheck",
					"sqlfluff",
					"tflint",
					"yamllint",
					--
					-- Formatters
					-- These should be installed manually if needed
					-- "autopep8",
					-- "black",
					"beautysh",
					"isort",
					"markdownlint",
					"shfmt",
					"stylua",
				},
			},
		},
		{
			"jay-babu/mason-nvim-dap.nvim",
			-- overrides `require("mason-nvim-dap").setup(...)`
			opts = {
				-- ensure_installed = { "python" },
			},
		},
	},

	-- PLANNED: consider heirline customization
	-- 	https://github.com/julianschuler/dotfiles/blob/6d7fa0c4a1317c242858f8eb24d8f7474756f9ce/astronvim/lua/user/init.lua#L133-L156

	-- Customize Heirline options
	heirline = {
		-- -- Customize different separators between sections
		-- separators = {
		--   breadcrumbs = " > ",
		--   tab = { "", "" },
		-- },
		-- -- Customize colors for each element each element has a `_fg` and a `_bg`
		-- colors = function(colors)
		--   colors.git_branch_fg = astronvim.get_hlgroup "Conditional"
		--   return colors
		-- end,
		-- -- Customize attributes of highlighting in Heirline components
		-- attributes = {
		--   -- styling choices for each heirline element, check possible attributes with `:h attr-list`
		--   git_branch = { bold = true }, -- bold the git branch statusline component
		-- },
		-- -- Customize if icons should be highlighted
		-- icon_highlights = {
		--   breadcrumbs = false, -- LSP symbols in the breadcrumbs
		--   file_icon = {
		--     winbar = false, -- Filetype icon in the winbar inactive windows
		--     statusline = true, -- Filetype icon in the statusline
		--     tabline = true, -- Filetype icon in the tabline
		--   },
		-- },
	},

	-- This function is run last and is a good place to configuring
	-- augroups/autocommands and custom filetypes also this just pure lua so
	-- anything that doesn't fit in the normal config locations above can go here
	polish = function()
		-- Set up custom filetypes
		-- vim.filetype.add {
		--   extension = {
		--     foo = "fooscript",
		--   },
		--   filename = {
		--     ["Foofile"] = "fooscript",
		--   },
		--   pattern = {
		--     ["~/%.config/foo/.*"] = "fooscript",
		--   },
		-- }
	end,
}

return config
