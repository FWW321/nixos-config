# filepath: ~/nixos-config/modules/user/editor/snacks.nix
# snacks.nvim 多合一 UI：dashboard、explorer、terminal、picker、indent 等
let
  fwwLogo = ''
    ███████╗██╗    ██╗██╗    ██╗
    ██╔════╝██║    ██╗██║    ██╗
    █████╗  ██║ █╗ ██║██║ █╗ ██║
    ██╔══╝  ██║███╗██║██║███╗██║
    ██║     ╚███╔███╔╝╚███╔███╔╝
    ╚═╝      ╚══╝╚══╝  ╚══╝╚══╝
  '';
in
{
  programs.nixvim.plugins.snacks = {
    enable = true;
    settings = {
      bigfile.enabled = true;

      explorer = {
        enabled = true;
        replace_netrw = true;
        focused = true;
        preview = "hover";
      };

      terminal = {
        enabled = true;
        win = {
          position = "bottom";
          wo = {
            winbar = " ";
          };
        };
      };

      input.enabled = true;
      zen.enabled = true;
      scratch.enabled = true;

      dashboard = {
        enabled = true;
        preset = {
          header = fwwLogo;
          keys = [
            {
              icon = " ";
              key = "f";
              desc = "Find File";
              action = ":lua Snacks.dashboard.pick('files')";
            }
            {
              icon = " ";
              key = "n";
              desc = "New File";
              action = ":ene | startinsert";
            }
            {
              icon = " ";
              key = "g";
              desc = "Find Text";
              action = ":lua Snacks.dashboard.pick('live_grep')";
            }
            {
              icon = " ";
              key = "r";
              desc = "Recent Files";
              action = ":lua Snacks.dashboard.pick('oldfiles')";
            }
            {
              icon = " ";
              key = "c";
              desc = "Config";
              action =
                ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})";
            }
            {
              icon = " ";
              key = "s";
              desc = "Restore Session";
              section = "session";
            }
            {
              icon = " ";
              key = "q";
              desc = "Quit";
              action = ":qa";
            }
          ];
        };
        sections = [
          { section = "header"; }
          { section = "keys";
            gap = 1;
            padding = 1;
          }
        ];
      };

      indent = {
        enabled = true;
        indent = {
          char = "│";
          only_scope = false;
          only_current = true;
          hl = [
            "SnacksIndent1"
            "SnacksIndent2"
            "SnacksIndent3"
            "SnacksIndent4"
            "SnacksIndent5"
            "SnacksIndent6"
          ];
        };
        scope = {
          enabled = true;
          char = "│";
          underline = true;
          only_current = true;
        };
        chunk.enabled = false;
        animate = {
          enabled = true;
          style = "out";
          easing = "linear";
          duration = {
            step = 20;
            total = 500;
          };
        };
      };

      scroll = {
        enabled = true;
        animate = {
          duration = {
            step = 10;
            total = 200;
          };
          easing = "linear";
        };
      };

      lazygit = {
        enabled = true;
        configure = true;
      };

      notifier = {
        enabled = true;
        timeout = 3000;
        style = "fancy";
        top_down = true;
      };

      quickfile.enabled = true;

      statuscolumn = {
        enabled = true;
        folds = {
          open = false;
          git_hl = true;
        };
      };

      words = {
        enabled = true;
        debounce = 200;
      };

      scope = {
        enabled = true;
        min_size = 2;
        cursor = true;
        edge = true;
        debounce = 30;
      };

      picker = {
        enabled = true;
        matcher = {
          fuzzy = true;
          smartcase = true;
          ignorecase = true;
          filename_bonus = true;
          file_pos = true;
        };
        formatters = {
          file = {
            filename_first = true;
            git_status_hl = true;
          };
        };
        sources = {
          files = {
            hidden = false;
            ignored = false;
          };
          buffers.sort_lastused = true;
          grep.pattern = "\\b";
        };
        win = {
          input = {
            keys = {
              "<C-c>" = "close";
            };
          };
        };
      };

      rename.enabled = true;
      gitbrowse.enabled = true;
      profiler.enabled = true;
    };
  };
}
