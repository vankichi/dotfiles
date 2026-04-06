local keymap = vim.api.nvim_set_keymap

keymap("n", "<CR>", "o<Esc>", { noremap = true, silent = true })
keymap("c", "<C-a>", "<Home>", { noremap = true })
keymap("i", "<C-a>", "<Home>", { noremap = true })
keymap("c", "<C-e>", "<End>", { noremap = true })
keymap("i", "<C-e>", "<End>", { noremap = true })
keymap("c", "<C-l>", "<Right>", { noremap = true })
keymap("i", "<C-l>", "<Right>", { noremap = true })
keymap("c", "<C-h>", "<Left>", { noremap = true })
keymap("i", "<C-h>", "<Left>", { noremap = true })
keymap("i", "<C-v>", "<ESC><C-v>", { noremap = true })
keymap("n", "<S-Tab>", "<<", { noremap = true })

-- 折り返した行を複数行として移動
keymap("n", "j", "gj", { noremap = true, silent = true })
keymap("n", "k", "gk", { noremap = true, silent = true })
keymap("n", "gj", "j", { noremap = true, silent = true })
keymap("n", "gk", "k", { noremap = true, silent = true })

-- ウィンドウの移動をCtrlキーと方向指定でできるように
keymap("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
keymap("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
keymap("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
keymap("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

-- Esc2回で検索のハイライトを消す
keymap("n", "<Esc><Esc>", ":<C-u>nohlsearch<CR>", { noremap = true, silent = true })

-- gをバインドキーとしてタブ操作
-- keymap("n", "gc", ":<C-u>tabnew<CR>", {noremap = true, silent = true})
-- keymap("n", "gx", ":<C-u>tabclose<CR>", {noremap = true, silent = true})
-- keymap("n", "gn", "gt", {noremap = true, silent = true})
-- keymap("n", "gp", "gT", {noremap = true, silent = true})

-- g+oで現在開いている以外のタブを全て閉じる
keymap("n", "go", ":<C-u>tabonly<CR>", { noremap = true, silent = true })

keymap("n", ";", ":", { noremap = true })
keymap("i", "<C-s>", "<esc>:w<CR>", { noremap = true })
keymap("n", "<C-q>", ":qall<CR>", { noremap = true })
keymap("n", "q", ":q<CR>", { noremap = true })

---@telescope
keymap("n", "<leader><leader>",
":lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown({}))<CR>",
{ noremap = true, silent = true })
keymap("n", "<leader>fg", ":lua require('telescope.builtin').live_grep(require('telescope.themes').get_dropdown({}))<CR>",
{ noremap = true, silent = true })
keymap("n", "<leader>fb", ":lua require('telescope.builtin').buffers(require('telescope.themes').get_dropdown({}))<CR>",
{ noremap = true, silent = true })
keymap("n", "<leader>fh", ":lua require('telescope.builtin').help_tags(require('telescope.themes').get_dropdown({}))<CR>",
{ noremap = true, silent = true })

---@format
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    local ft = vim.bo.filetype

    -- Lua: space 2
    if ft == "lua" then
      vim.bo.expandtab = true
      vim.bo.shiftwidth = 2
      vim.bo.tabstop = 2
      vim.bo.softtabstop = 2

    -- Go: tab 4
    elseif ft == "go" then
      vim.bo.expandtab = false
      vim.bo.shiftwidth = 4
      vim.bo.tabstop = 4

    -- JS / TS: space 2
    elseif ft == "javascript" or ft == "typescript" then
      vim.bo.expandtab = true
      vim.bo.shiftwidth = 2
      vim.bo.tabstop = 2
      vim.bo.softtabstop = 2

    -- Python: space 4
    elseif ft == "python" then
      vim.bo.expandtab = true
      vim.bo.shiftwidth = 4
      vim.bo.tabstop = 4
      vim.bo.softtabstop = 4
    end
  end,
})

