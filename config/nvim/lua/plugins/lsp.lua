local languages = {
	"bash",
	"c",
	"cpp",
	"dart",
	"dockerfile",
	"fish",
	"git_config",
	"go",
	"gomod",
	"gosum",
	"gpg",
	"graphql",
	"helm",
	"html",
	"javascript",
	"json",
	-- "kotolin",
	"lua",
	"make",
	"markdown",
	"markdown_inline",
	"rust",
	"tsx",
	"typescript",
	"vim",
	"yaml",
}

local lsps = {
	-- "gopls",
	"lua_ls",
	"rust_analyzer",
	"dockerls",
	"clangd",
	"pyright",
        "ts_ls",
}

local on_attach = function(client, bufnr)
	local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
	local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end
end

return {
	---@syntax_highlight
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			local configs = require("nvim-treesitter.configs")
			configs.setup({
				ensure_installed = languages,
				sync_install = false,
				highlight = { enable = true },
				indent = { enable = false },
			})
		end
	},
	---@lsp
	{
		"neovim/nvim-lspconfig",
		event = "BufReadPre",
		dependencies = {
			{
				"williamboman/mason.nvim",
				config = function()
				    require("mason").setup()
				end,
				-- version: "^1.0.0",
			},
			{
				"williamboman/mason-lspconfig.nvim",
				opts = {
				    ensure_installed = lsps
				},
				config = function()
				    require("mason-lspconfig").setup()
				end,
			},
			{ "hrsh7th/cmp-nvim-lsp" },
		},
		config = function()
			local lspconfig = require("lspconfig")
			-- local cmp_lsp = require("cmp_nvim_lsp")
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			-- local capabilities = cmp_lsp.default_capabilities()
			for _, server_name in ipairs(lsps) do
				vim.lsp.config(server_name, {capabilities})
			end
			vim.lsp.config("gopls", {
				cmd = { "gopls" },
				capabilities = capabilities,
				settings = {
					gopls = {
						experimentalPostfixCompletions = true,
						analyses = {
							unusedparams = true,
							shadow = true,
						},
						buildFlags = {"-tags=e2e" },
						staticcheck = true,
					},
				},
				init_options = {
					usePlaceholders = true,
				},
			})
		end,
	},
	---@completion
	{
		"hrsh7th/nvim-cmp",
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			{ "f3fora/cmp-spell", event = "InsertEnter" },
			{ "hrsh7th/cmp-buffer", event = "InsertEnter" },
			{ "hrsh7th/cmp-calc", event = "InsertEnter" },
			{ "hrsh7th/cmp-cmdline", event = "ModeChanged" },
			{ "hrsh7th/cmp-emoji", event = "InsertEnter" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "hrsh7th/cmp-nvim-lsp-document-symbol", event = "InsertEnter" },
			{ "hrsh7th/cmp-nvim-lsp-document-symbol", event = "InsertEnter" },
			{ "hrsh7th/cmp-nvim-lsp-signature-help", event = "InsertEnter" },
			{ "hrsh7th/cmp-nvim-lua", event = "InsertEnter" },
			{ "hrsh7th/cmp-path", event = "InsertEnter" },
			{ "ray-x/cmp-treesitter", event = "InsertEnter" },
			---@Go
			{
				"ray-x/go.nvim",
				ft = { "go" },
				config = true,
				opts = {
					gofmt = "gofumpt",
					goimports = "strictgoimports",
					lsp_cfg = false,
				},
			},
			---@snippets
			{
				"L3MON4D3/LuaSnip",
				build = "make install_jsregexp",
				event = "InsertEnter",
				config = function()
					require("luasnip").config.set_config({
						history = true,
						updateevents = "TextChanged,TextChangedI",
					})
					require("luasnip.loaders.from_vscode").lazy_load()
				end,
			},
			{ "saadparwaiz1/cmp_luasnip", event = "InsertEnter" },
			{ "rafamadriz/friendly-snippets", event = "InsertEnter" },
			---@icon
			{ "onsails/lspkind.nvim", event = "InsertEnter" },
			---@copilot TODO
		},
		config = function()
			local has_words_before = function()
				local line, col = unpack(vim.api.nvim_win_get_cursor(0))
				return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
			end
			local feedkey = function(key, mode)
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), mode, true)
			end
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			local lspkind = require("lspkind")
			local opts = {
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end
				},
				window = {
					completion = cmp.config.window.bordered({
						border = "single",
						col_offset = -3,
						side_padding = 0,
					}),
					documentation = cmp.config.window.bordered({
						winhiglight = "NormalFloat:CompeDocumentation,FloatBorder:TelescopeBorder",
					}),
				},
				mapping = cmp.mapping.preset.insert({
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()  -- LuaSnip でスニペットを展開またはジャンプ
						elseif has_words_before() then
							cmp.complete()
						else
							fallback()  -- デフォルトの <Tab> の動作
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function()
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)  -- LuaSnip で前のスニペットへジャンプ
						end
					end, { "i", "s" }),
					["<C-d>"] = cmp.mapping.scroll_docs(-4),
					["<C-u>"] = cmp.mapping.scroll_docs(4),
					["<C-e>"] = cmp.mapping.close(),
					["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
				}),
				sources = cmp.config.sources({
					---@Copilot_Source
					-- { name = "copilot", group_index = 2 },
					-- { name = "copilot_cmp", group_index = 2 },
					---@Other_Sources
					{ name = "nvim_lsp", group_index = 2 },
					{ name = "nvim_lsp_signature_help", group_index = 2 },
					{ name = "nvim_lua", group_index = 2 },
					{ name = "luasnip", group_index = 2 },
					{ name = "buffer", get_bufnrs = vim.api.nvim_list_bufs, group_index = 2 },
					{ name = "look", group_index = 2 },
					{ name = "path", group_index = 2 },
					{ name = "cmdline" },
					{ name = "git" },
				}),
				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol_text",
						preset = "codicons",
						-- with_text = false,
						maxwidth = 50,
						ellipsis_char = "...",
						menu = {
							copilot = "[COP]",
							nvim_lua = "[LUA]",
							nvim_lsp = "[LSP]",
							cmp_tabnine = "[TN]",
							luasnip = "[LSN]",
							buffer = "[Buf]",
							path = "[PH]",
							look = "[LK]",
						},
						symbol_map = {
							Array = "",
							Boolean = "",
							Class = " ",
							Color = " ",
							Constant = " ",
							Constructor = " ",
							Copilot = "",
							Enum = " ",
							EnumMember = " ",
							Event = " ",
							Field = " ",
							File = " ",
							Folder = " ",
							Function = " ",
							Interface = " ",
							Key = "",
							Keyword = " ",
							Method = " ",
							Module = " ",
							Namespace = "",
							Null = "",
							Number = "",
							Object = "",
							Operator = " ",
							Package = "",
							Property = " ",
							Reference = " ",
							Snippet = " ",
							String = "",
							Struct = " ",
							Text = " ",
							TypeParameter = " ",
							Unit = " ",
							Value = " ",
							Variable = " ",
						},
					}),
				},
				-- 補完動作設定
				completion = {
					completeopt = 'menu,menuone,noselect',  -- メニューの表示
				},
				-- 予測テキスト（選択候補）を表示
				experimental = {
					ghost_text = true,  -- 補完候補を選択前に表示
				},
			}
			cmp.setup(opts)
		end
	}

	-- {
	-- 	"hrsh7th/nvim-cmp",
	-- 	event = { "InsertEnter", "CmdlineEnter" },
	-- 	dependencies = {
-- 		{ "ray-x/cmp-treesitter", event = "InsertEnter" },
	-- 		{
	-- 			"petertriho/cmp-git",
	-- 			config = true,
	-- 			event = "InsertEnter",
	-- 			dependencies = { "nvim-lua/plenary.nvim" },
	-- 		},
	-- 		{ "octaltree/cmp-look", event = "InsertEnter" },
	-- 	},
	-- 	config = function()
	-- 		local cmp = require("cmp")
	-- 		local luasnip = require("luasnip")
	-- 		local lspkind = require("lspkind")
	-- 		local opts = {
	-- 			snippet = {
	-- 				expand = function(args)
	-- 					luasnip.lsp_expand(args.body)
	-- 				end,
	-- 			},
	-- 		mapping = {
	-- 			['<C-p>'] = cmp.mapping.select_prev_item(),
	-- 			['<C-n>'] = cmp.mapping.select_next_item(),
	-- 			['<C-y>'] = cmp.mapping.confirm({ select = true }),
	-- 			['<C-e>'] = cmp.mapping.close(),
	-- 		},
	-- 			sources = cmp.config.sources({
	-- 				-- Copilot Source
	-- 				{ name = "copilot", group_index = 2 },
	-- 				{ name = "copilot_cmp", group_index = 2 },
	-- 				-- Other Sources
	-- 				{ name = "nvim_lsp", group_index = 2 },
	-- 				{ name = "nvim_lsp_signature_help" },
	-- 				{ name = "luasnip", group_index = 2 },
	-- 				-- { name = "buffer", get_bufnrs = vim.api.nvim_list_bufs, group_index = 2 },
	-- 				{ name = "look", group_index = 2 },
	-- 				{ name = "path", group_index = 2 },
	-- 				{ name = "cmdline" },
	-- 				{ name = "git" },
	-- 			}),
	-- 		}
	-- 		cmp.setup(opts)
	-- 	end,
	-- },
	-- {
	-- 	"nathom/filetype.nvim",
	-- 	lazy = false,
	-- 	config = true,
	-- 	opts = {
	-- 		overrides = {
	-- 			extensions = {},
	-- 			literal = {},
	-- 			complex = {
	-- 				[".*git/config"] = "gitconfig",
	-- 			},
	-- 			function_extensions = {
	-- 				["cpp"] = function()
	-- 					vim.bo.filetype = "cpp"
	-- 					vim.bo.cinoptions = vim.bo.cinoptions .. "L0"
	-- 				end,
	-- 				["pdf"] = function()
	-- 					vim.bo.filetype = "pdf"
	-- 					fn.jobstart("open -a skim " .. '"' .. fn.expand("%") .. '"')
	-- 				end,
	-- 			},
	-- 			function_literal = {
	-- 				Brewfile = function()
	-- 					vim.cmd("syntax off")
	-- 				end,
	-- 			},
	-- 			function_complex = {
	-- 				["*.math_notes/%w+"] = function()
	-- 					vim.cmd("iabbrev $ $$")
	-- 				end,
	-- 			},
	-- 			shebang = {
	-- 				dash = "sh",
	-- 			},
	-- 		},
	-- 	},
	-- },
}
