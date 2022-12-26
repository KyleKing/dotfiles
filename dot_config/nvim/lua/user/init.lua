--              AstroNvim Configuration Table
-- All configuration changes should go inside of the table below
-- You can think of a Lua "table" as a dictionary like data structure the
-- normal format is "key = value". These also handle array like data structures
-- where a value with no key simply has an implicit numeric key
local config = {

	-- Configure AstroNvim updates
	updater = {
		remote = "origin", -- remote to use
		channel = "stable", -- "stable" or "nightly"
		version = "latest", -- "latest", tag name, or regex search like "v1.*" to only do updates before v2 (STABLE ONLY)
		branch = "main", -- branch name (NIGHTLY ONLY)
		commit = nil, -- commit hash (NIGHTLY ONLY)
		pin_plugins = nil, -- nil, true, false (nil will pin plugins on stable only)
		skip_prompts = false, -- skip prompts about breaking changes
		show_changelog = true, -- show the changelog after performing an update
		auto_reload = true, -- automatically reload and sync packer after a successful update
		auto_quit = true, -- automatically quit the current session after a successful update
		-- remotes = { -- easily add new remotes to track
		--   ["remote_name"] = "https://remote_url.come/repo.git", -- full remote url
		--   ["remote2"] = "github_user/repo", -- GitHub user/repo shortcut,
		--   ["remote3"] = "github_user", -- GitHub user assume AstroNvim fork
		-- },
	},

	-- Set colorscheme to use
	-- colorscheme = "default_theme",
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
			-- set to true or false etc.
			colorcolumn = "80,120",
			relativenumber = true, -- sets vim.opt.relativenumber
			number = true, -- sets vim.opt.number
			spell = false, -- sets vim.opt.spell
			signcolumn = "auto", -- sets vim.opt.signcolumn to auto
			wrap = true, -- sets vim.opt.wrap
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

	-- Set dashboard header
	header = {
		-- " █████  ███████ ████████ ██████   ██████",
		-- "██   ██ ██         ██    ██   ██ ██    ██",
		-- "███████ ███████    ██    ██████  ██    ██",
		-- "██   ██      ██    ██    ██   ██ ██    ██",
		-- "██   ██ ███████    ██    ██   ██  ██████",
		-- " ",
		"    ███    ██ ██    ██ ██ ███    ███",
		"    ████   ██ ██    ██ ██ ████  ████",
		"    ██ ██  ██ ██    ██ ██ ██ ████ ██",
		"    ██  ██ ██  ██  ██  ██ ██  ██  ██",
		"    ██   ████   ████   ██ ██      ██",
	},

	-- Default theme configuration
	default_theme = {
		-- Modify the color palette for the default theme
		colors = { fg = "#abb2bf", bg = "#1e222a" },
		highlights = function(hl) -- or a function that returns a new table of colors to set
			local C = require("default_theme.colors")

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
			bufferline = true,
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
	diagnostics = { virtual_text = true, underline = true },

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

		-- override the mason server-registration function
		-- server_registration = function(server, opts)
		--   require("lspconfig")[server].setup(opts)
		-- end,

		-- Add overrides for LSP server settings, the keys are the name of the server
		["server-settings"] = {
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
							flake8 = { enabled = true, ignore = { "E501" } },
							isort = { enabled = true }, -- FYI: Use isort from Packer instead
							mccabe = { enabled = false },
							pycodestyle = { enabled = false },
							pydocstyle = { enabled = false },
							pyflakes = { enabled = false },
							pylint = { enabled = true },
							pyls_flake8 = { enabled = false },
							pyls_mypy = { enabled = true },
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
			-- second key is the lefthand side of the map
			-- mappings seen under group name "Buffer"
			["<leader>bb"] = { "<cmd>tabnew<cr>", desc = "New tab" },
			["<leader>bc"] = {
				"<cmd>BufferLinePickClose<cr>",
				desc = "Pick to close",
			},
			["<leader>bj"] = { "<cmd>BufferLinePick<cr>", desc = "Pick to jump" },
			["<leader>bt"] = {
				"<cmd>BufferLineSortByTabs<cr>",
				desc = "Sort by tabs",
			},
			-- quick save
			-- ["<C-s>"] = { ":w!<cr>", desc = "Save File" },  -- change description but the same command
		},
		t = {
			-- setting a mapping to false will disable it
			-- ["<esc>"] = false,
		},
	},

	-- Configure plugins
	plugins = {
		init = {
			-- You can disable default plugins as follows:
			-- ["goolord/alpha-nvim"] = { disable = true },

			-- You can also add new plugins here as well:
			-- Add plugins, the packer syntax without the "use"
			-- { "andweeb/presence.nvim" },
			-- {
			--   "ray-x/lsp_signature.nvim",
			--   event = "BufRead",
			--   config = function()
			--     require("lsp_signature").setup()
			--   end,
			-- },

			-- Themes
			-- ["dracula/vim"] = {},  -- dracula
			["EdenEast/nightfox.nvim"] = {}, -- nightfox, duskfox
			-- ["folke/tokyonight.nvim"] = {},  -- tokyonight-storm
			-- ["joshdick/onedark.vim"] = {},  -- onedark
			-- ["rebelot/kanagawa.nvim"] = {}, -- kanagawa
			-- ["roflolilolmao/oceanic-next.nvim"] = {},  -- OceanicNext
			["sainnhe/everforest"] = { -- everforest
				-- PLANNED: Need to figure out how configuration works
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
			-- ["sickill/vim-monokai"] = {}, -- monokai
			-- ["sonph/onehalf"] = {}, -- onehalfdark

			-- Additional plugins
			["kylechui/nvim-surround"] = {},
			["sheerun/vim-polyglot"] = {},
			["folke/todo-comments.nvim"] = {
				requires = "nvim-lua/plenary.nvim",
				config = function()
					require("todo-comments").setup({})
				end,
			},
			-- ["ray-x/lsp_signature.nvim"] = {
			-- 	event = "BufRead",
			-- 	config = function()
			-- 		require("lsp_signature").setup()
			-- 	end,
			-- },
			["codota/tabnine-nvim"] = {
				config = function()
					require("tabnine").setup({
						disable_auto_comment = true,
						accept_keymap = "<Tab>",
						debounce_ms = 300,
						suggestion_color = { gui = "#808080", cterm = 244 },
					})
				end,
			},
		},
		-- All other entries override the require("<key>").setup({...}) call for default plugins
		["neo-tree"] = {
			filesystem = {
				filtered_items = {
					hide_gitignored = true,
					hide_dotfiles = false,
				},
			},
		},
		["null-ls"] = function(config) -- overrides `require("null-ls").setup(config)`
			-- config variable is the default configuration table for the setup function call
			local null_ls = require("null-ls")
			null_ls.setup({ debug = true })
			-- Check supported formatters and linters
			-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
			-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
			config.sources = {
				null_ls.builtins.formatting.stylua,
				-- FIXME: Can this use calcipy, black, or flake8 based on project?
				-- null_ls.builtins.formatting.black,
				-- null_ls.builtins.formatting.prettier.with({
				--     prefer_local = "node_modules/.bin",
				-- }),
				-- null_ls.builtins.formatting.eslint.with({
				--     prefer_local = "node_modules/.bin",
				-- }),
				-- null_ls.builtins.formatting.taplo,
				-- null_ls.builtins.formatting.terraform_fmt,
				null_ls.builtins.formatting.trim_newlines,
				null_ls.builtins.formatting.trim_whitespace,
				-- null_ls.builtins.formatting.uncrustify,
				-- Diagnostics
				-- null_ls.builtins.diagnostics.eslint.with({
				--     prefer_local = "node_modules/.bin",
				-- }),
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
				-- null_ls.builtins.diagnostics.shellcheck,
				-- null_ls.builtins.diagnostics.hadolint,
				--
				-- null_ls.builtins.code_actions.eslint.with({
				--     only_local = true
				-- }),
				-- null_ls.builtins.code_actions.gitsigns,
			}
			return config -- return final config table
		end,
		treesitter = { -- overrides `require("treesitter").setup(...)`
			-- ensure_installed = { "lua" },
			ensure_installed = { "lua", "python", "javascript", "html", "css", "json", "toml" },
		},
		-- PLANNED: consider heirline customization
		-- 	https://github.com/julianschuler/dotfiles/blob/6d7fa0c4a1317c242858f8eb24d8f7474756f9ce/astronvim/lua/user/init.lua#L133-L156
		--
		-- use mason-lspconfig to configure LSP installations
		["mason-lspconfig"] = { -- overrides `require("mason-lspconfig").setup(...)`
			-- ensure_installed = { "sumneko_lua" },
			-- "awk-language-server", "bash-language-server", "codeql", "dockerfile-language-server", "eslint-lsp", "lua-language-server", "pyright", "python-lsp-server", "sourcery:, "taplo", "terraform-ls", "tflint", "yaml-language-server"
		},
		-- use mason-null-ls to configure Formatters/Linter installation for null-ls sources
		["mason-null-ls"] = { -- overrides `require("mason-null-ls").setup(...)`
			-- ensure_installed = { "prettier", "stylua" },
			-- "actionlint", "codespell", "flake8", "jsonlint", "luacheck", "markdownlint", "proselint", "shellcheck", "sqlfluff", "tflint", "yamllint"
			-- "autopep8", "beautysh", "black", "isort", "markdownlint", "shfmt", "stylua"
		},
		["mason-nvim-dap"] = { -- overrides `require("mason-nvim-dap").setup(...)`
			-- ensure_installed = { "python" },
		},
	},

	-- LuaSnip Options
	luasnip = {
		-- Extend filetypes
		filetype_extend = {
			-- javascript = { "javascriptreact" },
		},
		-- Configure luasnip loaders (vscode, lua, and/or snipmate)
		vscode = {
			-- Add paths for including more VS Code style snippets in luasnip
			paths = {},
		},
	},

	-- CMP Source Priorities
	-- modify here the priorities of default cmp sources
	-- higher value == higher priority
	-- The value can also be set to a boolean for disabling default sources:
	-- false == disabled
	-- true == 1000
	cmp = {
		source_priority = {
			nvim_lsp = 1000,
			luasnip = 750,
			buffer = 500,
			path = 250,
		},
	},

	-- Modify which-key registration (Use this with mappings table in the above.)
	["which-key"] = {
		-- Add bindings which show up as group name
		register = {
			-- first key is the mode, n == normal mode
			n = {
				-- second key is the prefix, <leader> prefixes
				["<leader>"] = {
					-- third key is the key to bring up next level and its displayed
					-- group name in which-key top level menu
					["b"] = { name = "Buffer" },
				},
			},
		},
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
