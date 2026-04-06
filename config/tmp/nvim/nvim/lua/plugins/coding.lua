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
      pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
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
  {
    "copilotlsp-nvim/copilot-lsp",
  },
  {
    "zbirenbaum/copilot.lua",
    -- dependencies = { "copilotlsp-nvim/copilot-lsp" },
    cmd = "Copilot",
    -- build = ":Copilot auth",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false }, -- copilot-cmp と干渉するのでOFF
      panel = { enabled = false },-- same above
    },
  },
  {
    "zbirenbaum/copilot-cmp",
    dependencies = { "zbirenbaum/copilot.lua" },
    config = function()
      require("copilot_cmp").setup()
    end,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    build = "make tiktoken",
    opts = {
      debug = false,
      window = {
	layout = "vertical",
	width = 0.3,
      }
      -- See Configuration section for options
    },
    -- See Commands section for default commands if you want to lazy load on them
    config = function()
      require("CopilotChat").setup({
        prompts = {
          Explain = {
              prompt = "選択したコードの説明を日本語で書いてください",
              mapping = "<leader>ce",
          },
          Review = {
              prompt = "コードを日本語でレビューしてください",
              mapping = "<leader>cr",
          },
          Fix = {
              prompt = "このコードには問題があります。バグを修正したコードを表示してください。説明は日本語でお願いします",
              mapping = "<leader>cf",
          },
          Optimize = {
              prompt = "選択したコードを最適化し、パフォーマンスと可読性を向上させてください。説明は日本語でお願いします",
              mapping = "<leader>co",
          },
          Docs = {
              prompt = "選択したコードに関するドキュメントコメントを日本語で生成してください",
              mapping = "<leader>cd",
          },
          Tests = {
              prompt = "選択したコードの詳細なユニットテストを書いてください。説明は日本語でお願いします",
              mapping = "<leader>ct",
          },
          Commit = {
              prompt = require("CopilotChat.config.prompts").Commit.prompt,
              mapping = "<leader>cco",
              selection = require("CopilotChat.select").gitdiff,
          },
        },
      })
    end,

    -- -- See Commands section for default commands if you want to lazy load on them
    -- keys = {
    --   {
    --     "<leader>cc",
    --     function()
    --       require("CopilotChat").toggle()
    --     end,
    --     desc = "CopilotChat - Toggle",
    --   },
    --   {
    --     "<leader>cch",
    --     function()
    --       local actions = require("CopilotChat.actions")
    --       require("CopilotChat.integrations.telescope").pick(actions.help_actions())
    --     end,
    --     desc = "CopilotChat - Help actions",
    --   },
    --   { "<leader>ccp",
    --     function()
    --       local actions = require("CopilotChat.actions")
    --       require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
    --     end,
    --     desc = "CopilotChat - Prompt actions",
    --   },
    -- },
  },
}
