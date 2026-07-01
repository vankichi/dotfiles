-- lua/plugins/lsp.lua
-- mason-lspconfig v2 対応（setup_handlers は廃止）
-- Neovim 0.11+ 想定: vim.lsp.config() + vim.lsp.enable()

local treesitter_languages = {
	"bash", "c", "cpp", "dart", "dockerfile", "fish", "git_config",
	"go", "gomod", "gosum", "gpg", "graphql", "helm",
	"html", "css", "javascript", "typescript", "tsx", "json",
	"lua", "make", "markdown", "markdown_inline",
	"rust", "vim", "yaml", "kotlin",
}

return {
	-- Treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = treesitter_languages,
				sync_install = false,
				highlight = { enable = false },
			})
		end,
	},

	-- LSP
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			{
				"williamboman/mason.nvim",
				config = function()
					require("mason").setup()
				end,
			},
			{
				"mason-org/mason-lspconfig.nvim",
				-- v2系を想定（setup_handlers無し）
				config = function()
					require("mason-lspconfig").setup({
						-- automatic_enable は「インストール済みサーバーの有効化」のみ。
						-- インストール自体は ensure_installed が無いと行われないため、
						-- 設定対象のサーバーを明示して再現可能にする。
						ensure_installed = {
							"ts_ls", -- TypeScript / JavaScript
							"tailwindcss",
							"html",
							"cssls",
							"lua_ls",
							"kotlin_language_server",
							"dockerls",
						},
						-- v2では automatic_enable が導入され remember: デフォルトで有効
						-- 明示したいなら ↓
						automatic_enable = true,
					})
				end,
			},
			{ "hrsh7th/cmp-nvim-lsp" },
		},
		config = function()
			local cmp_lsp = require("cmp_nvim_lsp")
			local capabilities = cmp_lsp.default_capabilities(vim.lsp.protocol.make_client_capabilities())

			-- tsserver / ts_ls の揺れを吸収（存在する方を使う）
			local ts_name = "tsserver"
			do
				local ok, configs = pcall(require, "lspconfig.configs")
				if ok and configs and configs.ts_ls ~= nil then
					ts_name = "ts_ls"
				end
			end

			local servers = {
				gopls = {
					cmd = { "gopls" },
					capabilities = capabilities,
					settings = {
						gopls = {
							experimentalPostfixCompletions = true,
							analyses = { unusedparams = true, shadow = true },
							buildFlags = { "-tags=e2e" },
							staticcheck = true,
						},
					},
					init_options = { usePlaceholders = true },
				},

				[ts_name] = {
					capabilities = capabilities,
				},

				tailwindcss = { capabilities = capabilities },
				html = { capabilities = capabilities },
				cssls = { capabilities = capabilities },
				rust_analyzer = { capabilities = capabilities },

				lua_ls = {
					capabilities = capabilities,
					settings = {
						Lua = {
							diagnostics = { globals = { "vim" } },
							workspace = { checkThirdParty = false },
							telemetry = { enable = false },
							format = { enable = true },
						},
					},
				},

				kotlin_language_server = { capabilities = capabilities },

				dockerls = { capabilities = capabilities },
			}

			-- 1) まず Neovim に「各サーバーの設定」を登録
			local enable_list = {}
			for name, opts in pairs(servers) do
				vim.lsp.config(name, opts)
				table.insert(enable_list, name)
			end

			-- 2) 有効化（インストール済みのものが attach される）
			-- mason-lspconfig v2 の automatic_enable が有効なら、これ自体は不要な場合もあるが、
			-- 明示すると挙動が読みやすいので残す。
			vim.lsp.enable(enable_list)
		end,
	},

	-- Completion（元の構成を維持）
	{
		"hrsh7th/nvim-cmp",
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			{ "hrsh7th/cmp-buffer",                  event = "InsertEnter" },
			{ "hrsh7th/cmp-cmdline",                 event = "ModeChanged" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "hrsh7th/cmp-nvim-lsp-signature-help", event = "InsertEnter" },
			{ "hrsh7th/cmp-nvim-lua",                event = "InsertEnter" },
			{ "hrsh7th/cmp-path",                    event = "InsertEnter" },
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
			{ "saadparwaiz1/cmp_luasnip",     event = "InsertEnter" },
			{ "rafamadriz/friendly-snippets", event = "InsertEnter" },
			{ "onsails/lspkind.nvim",         event = "InsertEnter" },
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			local lspkind = require("lspkind")

			local function has_words_before()
				local line, col = vim.api.nvim_win_get_cursor(0)
				return col ~= 0
						and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
			end

			cmp.setup({
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-j>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						elseif has_words_before() then
							cmp.complete()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<C-k>"] = cmp.mapping(function()
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)
						end
					end, { "i", "s" }),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "nvim_lsp_signature_help" },
					{ name = "nvim_lua" },
					{ name = "luasnip" },
					{ name = "copilot" },
					{ name = "buffer" },
					{ name = "path" },
					{ name = "cmdline" },
				}),
				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol_text",
						preset = "codicons",
						maxwidth = 50,
						ellipsis_char = "...",
					}),
				},
				sorting = {
					priority_weight = 2,
					comparators = {
						function(e1, e2)
							local k = require("cmp").lsp.CompletionItemKind
							if e1:get_kind() == k.Variable and e2:get_kind() ~= k.Variable then
								return false
							end
							if e2:get_kind() == k.Variable and e1:get_kind() ~= k.Variable then
								return true
							end
						end,
						require("cmp.config.compare").offset,
						require("cmp.config.compare").exact,
						require("cmp.config.compare").score,
					},
				},
				completion = { completeopt = "menu,menuone,noselect" },
				experimental = { ghost_text = true },
			})
		end,
	},
}
