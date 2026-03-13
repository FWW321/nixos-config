# filepath: ~/nixos-config/modules/user/editor.nix
{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      nixfmt
    ];
    globals.mapleader = " ";
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 4;
      tabstop = 4;
      expandtab = true;
      smartindent = true;
      wrap = false;
      ignorecase = true;
      smartcase = true;
      cursorline = true;
      clipboard = "unnamedplus";
      updatetime = 250;
      signcolumn = "yes";
    };
    plugins = {
      lualine.enable = true;
      bufferline.enable = true;
      telescope.enable = true;
      web-devicons.enable = true;
      which-key.enable = true;
      nvim-autopairs.enable = true;
      comment.enable = true;
      nvim-surround.enable = true;
      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
        };
      };
      gitsigns = {
        enable = true;
      };
      treesitter = {
        enable = true;
        settings.highlight.enable = true;
      };
      lsp = {
        enable = true;
        servers = {
          zls.enable = true;
          rust_analyzer = {
            enable = true;
            installCargo = true;
            installRustc = true;
          };
          ts_ls.enable = true;
          nixd.enable = true;
        };
      };
      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            lsp_fallback = true;
            timeout_ms = 500;
          };
          notify_on_error = false;
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            rust = [ "rustfmt" ];
            "_" = [ "trim_whitespace" ];
          };
        };
      };
      cmp = {
        enable = true;
        autoEnableSouces = true;
        settings.mapping = {
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
        };
      };
      keymaps = [
        {
          mode = "n";
          key = "<leader>fm";
          action = "<cmd>lua require('conform').format()<CR>";
          option.desc = "Format Code";
        }
        {
          mode = "n";
          key = "<C-h>";
          action = "<C-w>h";
          option.desc = "移动到左侧分屏";
        }
        {
          mode = "n";
          key = "<C-l>";
          action = "<C-w>l";
          option.desc = "移动到右侧分屏";
        }
        {
          mode = "n";
          key = "<C-j>";
          action = "<C-w>j";
          option.desc = "移动到下方分屏";
        }
        {
          mode = "n";
          key = "<C-k>";
          action = "<C-w>k";
          option.desc = "移动到上方分屏";
        }
        {
          mode = "n";
          key = "<leader>h";
          action = "<cmd>nohlsearch<CR>";
          option.desc = "清除搜索高亮";
        }
        {
          mode = "n";
          key = "<leader>e";
          action = "<cmd>Neotree toggle<CR>";
          options.desc = "Toggle Explorer";
        }
        {
          mode = "n";
          key = "<leader>ff";
          action = "<cmd>Telescope find_files<CR>";
          options.desc = "Find Files";
        }
        {
          mode = "n";
          key = "<leader>fg";
          action = "<cmd>Telescope live_grep<CR>";
          option.desc = "Live Grep";
        }
        {
          mode = "n";
          key = "<S-h>";
          action = "<cmd>bprevious<CR>";
          option.desc = "Prev Buffer";
        }
        {
          mode = "n";
          key = "<S-l>";
          action = "<cmd>bnext<CR>";
          option.desc = "Next Buffer";
        }
        {
          mode = "n";
          key = "<leader>c";
          action = "<cmd>bdelete<CR>";
          option.desc = "Close Buffer";
        }
        {
          mode = "n";
          key = "<C-s>";
          action = "<cmd>w<CR>";
          option.desc = "Save";
        }
        {
          mode = "n";
          key = "<leader>q";
          action = "<cmd>q<CR>";
          option.desc = "Quit";
        }

        {
          mode = "i";
          key = "jk";
          action = "<Esc>";
          options.desc = "退出插入模式";
        }
        {
          mode = "i";
          key = "<C-a>";
          action = "<Home>";
          options.desc = "跳至行首";
        }
        {
          mode = "i";
          key = "<C-e>";
          action = "<End>";
          options.desc = "跳至行尾";
        }

        {
          mode = "v";
          key = "J";
          action = ":m '>+1<CR>gv=gv";
          options.desc = "将选中代码下移";
        }
        {
          mode = "v";
          key = "K";
          action = ":m '<-2<CR>gv=gv";
          options.desc = "将选中代码上移";
        }
        {
          mode = "v";
          key = "<";
          action = "<gv";
          options.desc = "向左缩进并保持选中";
        }
        {
          mode = "v";
          key = ">";
          action = ">gv";
          options.desc = "向右缩进并保持选中";
        }
      ];
    };
  };
}
