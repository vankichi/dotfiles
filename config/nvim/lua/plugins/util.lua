return {
	{
		"nvim-telescope/telescope.nvim",
		event = "VeryLazy",
		cmd = "Telescope",
		dependencies = {
			"nvim-lua/plenary.nvim"
		},
		config = function()
			local telescope = require("telescope")
			telescope.setup({
				defaults = {
					layoout_config = {
						vertical = { width = 0.8 },
					},
					mappings = {
					},
				},
				extensions = {
					file_browser = {
						-- disables netrw and use telescope-file-browser in its place
						mappings = {
							-- your custom insert mode mappings
						},
					},
				},
			})
		end
	}
}
