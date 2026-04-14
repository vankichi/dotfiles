local opt = vim.opt
-- --------------------
-- Encoding
-- --------------------
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.number = true
vim.scriptencoding = "utf-8"

-- -------------------------
-- ---- Default Setting ----
-- -------------------------
opt.completeopt = { "menu", "preview", "noinsert" }
opt.wrap = true
opt.synmaxcol = 2000
opt.showmatch = true
opt.matchtime = 2
opt.list = true
opt.listchars = { space = " ", tab = "> ", trail = "_", eol = "↲", extends = "»", precedes = "«", nbsp = "%" }
opt.display = "lastline"
opt.nrformats = ""
opt.virtualedit = "block"
opt.wildmenu = true
opt.wildmode = { "list:longest", "full" }
opt.autoread = true
opt.autowrite = true
opt.swapfile = false
opt.writebackup = false
opt.backup = false
opt.clipboard:append("unnamedplus")
opt.splitright = true
opt.splitbelow = true
opt.incsearch = true
opt.ignorecase = true
opt.wrapscan = true
opt.infercase = true
opt.smartcase = true
opt.laststatus = 2
opt.showcmd = true
opt.visualbell = true
vim.t_vb = ""
opt.errorbells = false
-- opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smarttab = true
opt.softtabstop = 0
opt.autoindent = true
opt.smartindent = true
opt.shiftround = true
opt.list = true
opt.whichwrap = "b,s,h,l,<,>,[,]"
opt.scrolloff = 5
opt.backspace = { "indent", "eol", "start" }
opt.matchpairs:append("<:>")
opt.switchbuf = "useopen"
opt.history = 100
opt.mouse = "a"
opt.lazyredraw = true
opt.ttyfast = true

opt.viminfo = "'100,/50,%,<1000,f50,s100,:100,c,h,!"
opt.shortmess:append("I")
opt.fileformat = "unix"
opt.fileformats = { "unix", "dos", "mac" }
opt.foldmethod = "manual"

if vim.fn.executable("zsh") == 1 then
	opt.shell = "zsh"
end

-- ----------------------
-- ---- Key mappings ----
-- ----------------------
vim.cmd("cnoreabbrev W! w!")
vim.cmd("cnoreabbrev Q! q!")
vim.cmd("cnoreabbrev Qall! qall!")
vim.cmd("cnoreabbrev Wq wq")
vim.cmd("cnoreabbrev Wa wa")
vim.cmd("cnoreabbrev wQ wq")
vim.cmd("cnoreabbrev WQ wq")
vim.cmd("cnoreabbrev W w")
vim.cmd("cnoreabbrev Q q")
vim.cmd("cnoreabbrev Qall qall")

-- ----------------------------
-- ---- AutoGroup Settings ----
-- ----------------------------
vim.cmd([[
augroup AutoGroup
    autocmd!
augroup END
]])

vim.cmd("command! -nargs=* Autocmd autocmd AutoGroup <args>")
vim.cmd("command! -nargs=* AutocmdFT autocmd AutoGroup FileType <args>")
vim.api.nvim_create_augroup("FileTypeIndent", { clear = true })
local function set_indent(tab, shift, expand)
	vim.bo.tabstop = tab
	vim.bo.shiftwidth = shift
	vim.bo.expandtab = expand
end
-- ------------------------------
-- ---- Indentation settings ----
-- ------------------------------
-- indentLine settings (assuming a plugin like 'IndentLine' is being used)
vim.g.indentLine_faster = 1
vim.api.nvim_set_keymap("n", "<silent><Leader>i", ":<C-u>IndentLinesToggle<CR>", { noremap = true, silent = true })
vim.api.nvim_create_autocmd("FileType", {
	group = "FileTypeIndent",
	pattern = { "js", "jsx", "ts", "tsx", "typescript", "typescriptreact", "javascript", "javascriptreact" },
	-- command = "setlocal expandtab sw=2 ts=2 completeopt=menu,menuone,preview,noselect,noinsert",
	callback = function()
		set_indent(2, 2, true)
	end
})

-- ------------------------------
-- ---- Window size settings ----
-- ------------------------------
vim.api.nvim_create_autocmd({"WinNew", "WinClosed"}, {
  callback = function()
    vim.cmd("wincmd =")
  end,
})

-- --------------------------------
-- ---- Auto-reload on change  ----
-- --------------------------------
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  command = "checktime",
})

