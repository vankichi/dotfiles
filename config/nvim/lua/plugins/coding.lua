return {
    {
        "JoosepAlviste/nvim-ts-context-commentstring",
        opts = {
            enable_autocmd = false,
        },
    },
    {
        "numToStr/Comment.nvim",
        opts = {},
        init = function()
            pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook()
        end,
        opts = {
            toggler = {
                line = "<C-c>",
            },
            opleader = {
                line = "<C-c>",
            },
        },
    },
	{
		"windwp/nvim-autopairs",
		opts = {
			disable_filetype = { "TelescopePrompt", "vim" },
		},
		config = true,
	},
}
