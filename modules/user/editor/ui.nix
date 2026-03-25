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
          {
            __unkey = true;
            mode = "n";
            "<leader>b" = { name = "Buffers"; __unkey = true; };
            "<leader>c" = { name = "Code"; __unkey = true; };
            "<leader>d" = { name = "Debug"; __unkey = true; };
            "<leader>f" = { name = "Find"; __unkey = true; };
            "<leader>g" = { name = "Git"; __unkey = true; };
            "<leader>s" = { name = "Search"; __unkey = true; };
            "<leader>t" = { name = "Tabs"; __unkey = true; };
            "<leader>u" = { name = "UI"; __unkey = true; };
            "<leader>w" = { name = "Windows"; __unkey = true; };
            "<leader>x" = { name = "Trouble"; __unkey = true; };
          }
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
