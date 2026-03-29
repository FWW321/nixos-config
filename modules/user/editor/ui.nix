# filepath: ~/nixos-config/modules/user/editor/ui.nix
# 状态栏、标签栏、图标、which-key、颜色渲染
{ ... }:

{
  programs.nixvim.plugins = {
    lualine = {
      enable = true;
      settings = {
        options = {
          globalstatus = true;
          theme = "auto";
          component_separators = {
            left = "";
            right = "";
          };
          section_separators = {
            left = "";
            right = "";
          };
          disabled_filetypes = {
            statusline = [ "dashboard" ];
            winbar = [ "dashboard" ];
          };
        };
        sections = {
          lualine_a = [ "mode" ];
          lualine_b = [ "branch" "diff" "diagnostics" ];
          lualine_c = [ "filename" ];
          lualine_x = [ "filetype" "encoding" ];
          lualine_y = [ "progress" ];
          lualine_z = [ "location" ];
        };
      };
    };

    bufferline = {
      enable = true;
      settings.options = {
        separator_style = "slope";
        diagnostics = "nvim_lsp";
        persist_buffer_sort = true;
        hover = {
          enabled = true;
          reveal = [ "close" ];
        };
        offsets = [
          {
            filetype = "snacks_explorer";
            text = "EXPLORER";
            highlight = "Directory";
            text_align = "center";
            separator = true;
          }
        ];
      };
    };

    web-devicons.enable = true;

    which-key = {
      enable = true;
      settings = {
        preset = "modern";
        show_help = false;
        spec = [
          { __unkeyed-1 = "<leader>b"; group = "Buffers"; mode = "n"; }
          { __unkeyed-1 = "<leader>c"; group = "Code"; mode = "n"; }
          { __unkeyed-1 = "<leader>f"; group = "Find"; mode = "n"; }
          { __unkeyed-1 = "<leader>g"; group = "Git"; mode = "n"; }
          { __unkeyed-1 = "<leader>s"; group = "Search"; mode = "n"; }
          { __unkeyed-1 = "<leader>t"; group = "Toggle"; mode = "n"; }
          { __unkeyed-1 = "<leader>u"; group = "UI"; mode = "n"; }
          { __unkeyed-1 = "<leader>w"; group = "Windows"; mode = "n"; }
          { __unkeyed-1 = "<leader>x"; group = "Trouble"; mode = "n"; }
        ];
      };
    };

    highlight-colors = {
      enable = true;
      lazyLoad.settings.ft = [
        "css"
        "scss"
        "html"
        "javascript"
        "javascriptreact"
        "typescript"
        "typescriptreact"
        "vue"
        "svelte"
      ];
      settings = {
        render = {
          background = true;
          foreground = false;
        };
        enable_tailwind = true;
      };
    };

    render-markdown = {
      enable = true;
      lazyLoad.settings.ft = [ "markdown" ];
    };
  };
}
