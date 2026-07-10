vim.api.nvim_create_user_command("Format", function()
  local view = vim.fn.winsaveview()
  local ft = vim.bo.filetype

  if ft == "go" then
    vim.lsp.buf.format({
      async = false,
      filter = function(client)
        return client.name == "gopls"
      end,
    })

  elseif ft == "lua" then
    vim.lsp.buf.format({
      async = false,
      filter = function(client)
        return client.name == "lua_ls"
      end,
    })

  elseif ft == "javascript" or ft == "typescript" then
    vim.lsp.buf.format({
      async = false,
      filter = function(client)
        return client.name == "tsserver"
      end,
    })

  elseif ft == "python" then
    vim.lsp.buf.format({
      async = false,
      filter = function(client)
        return client.name == "pyright"
      end,
    })

  else
    vim.lsp.buf.format({ async = false })
  end

  vim.fn.winrestview(view)
end, {})

vim.keymap.set("n", "<leader>f", ":Format<CR>", { desc = "Format buffer" })

