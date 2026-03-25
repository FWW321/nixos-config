# filepath: ~/nixos-config/modules/user/editor/plugins.nix
# 编辑增强、跳转、注释、Trouble、TODO、mini 系列
{ ... }:

{
  programs.nixvim.plugins = {
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

    trouble = {
      enable = true;
      lazyLoad.settings.cmd = [ "Trouble" ];
    };

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
  };
}
