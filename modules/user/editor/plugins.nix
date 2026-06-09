# filepath: ~/nixos-config/modules/user/editor/plugins.nix
# 编辑增强、跳转、注释、Trouble、TODO、mini 系列
{ ... }:

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

    # 不能 lazyLoad：nixvim 用 lz.n 做 lazy loading，快捷键通过 lazyLoad.settings.keys 定义才生效，
    # 全局 keymaps 里定义的快捷键无法触发 cmd 加载，Trouble 也很轻量，不值得折腾
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
}
