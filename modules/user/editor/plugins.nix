# filepath: ~/nixos-config/modules/user/editor/plugins.nix
# 编辑增强、跳转、注释、Trouble、TODO、mini 系列
{ config, pkgs, ... }:
{

  programs.nixvim.plugins = {
    lz-n.enable = true;

    flash = {
      enable = true;
      settings = {
        labels = "asdfghjklqwertyuiopzxcvbnm";
        label.uppercase = false;
        label.current = true;
        modes.char = {
          jump_labels = true;
          multi_line = true;
        };
      };
    };

    nvim-surround.enable = true;
    ts-comments.enable = true;
    lastplace.enable = true;

    trouble.enable = true;

    todo-comments = {
      enable = true;
      lazyLoad.settings.cmd = [ "TodoQuickFix" "TodoLocList" "TodoTrouble" "TodoTelescope" ];
    };

    mini-bracketed.enable = true;

    mini-ai = {
      enable = true;
      settings = {
        n_lines = 50;
        custom_textobjects = {
          o.__raw = "require('mini.ai').gen_spec.function_call({ name_pattern = '[%w_]+' })";
        };
      };
    };

    mini-move.enable = true;
    mini-pairs.enable = true;

    noice = {
      enable = true;
      settings = {
        presets = {
          bottom_search = false;
          command_palette = true;
          long_message_to_split = true;
          inc_rename = true;
          lsp_doc_border = true;
        };
        cmdline = {
          view = "cmdline_center";
          format = {
            cmdline = { pattern = "^:"; icon = ""; lang = "vim"; };
            search_down = { kind = "search"; pattern = "^/"; icon = " "; lang = "regex"; };
            search_up = { kind = "search"; pattern = "^%?"; icon = " "; lang = "regex"; };
          };
        };
        views = {
          cmdline_center = {
            backend = "popup";
            relative = "editor";
            position = { row = "40%"; col = "50%"; };
            size = { width = "60%"; height = "auto"; };
            border = { style = "rounded"; padding = [ 0 1 ]; };
          };
        };
        lsp.override = {
          "vim.lsp.util.convert_input_to_markdown_lines" = true;
          "vim.lsp.util.stylize_markdown" = true;
        };
      };
    };

  };

  programs.nixvim.extraConfigLuaPre = ''
    vim.env.ZHIPU_API_KEY = vim.fn.readfile("${config.sops.secrets.zhipu_api_key.path}")[1] or ""
  '';

  programs.nixvim.extraPlugins = [
    (pkgs.vimUtils.buildVimPlugin {
      pname = "multicursor.nvim";
      version = "1.0";
      src = pkgs.fetchFromGitHub {
        owner = "jake-stewart";
        repo = "multicursor.nvim";
        rev = "1.0";
        hash = "sha256-JHl8Z7ESrWus2I6Pe+6gmdgCAZOzAKX7kimy71sAoe4=";
      };
    })
    pkgs.vimPlugins.plenary-nvim
  ];

  programs.nixvim.extraConfigLua = ''
    require("multicursor-nvim").setup()

    local hl = vim.api.nvim_set_hl
    hl(0, "MultiCursorCursor", { reverse = true })
    hl(0, "MultiCursorVisual", { link = "Visual" })
    hl(0, "MultiCursorSign", { link = "SignColumn" })
    hl(0, "MultiCursorMatchPreview", { link = "Search" })
    hl(0, "MultiCursorDisabledCursor", { reverse = true })
    hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
    hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
  '';
}
