# filepath: ~/nixos-config/modules/user/editor/completion.nix
# 补全引擎（blink-cmp）
{ ... }:

{
  programs.nixvim.plugins = {
    blink-cmp = {
      enable = true;
      settings = {
        keymap = {
          preset = "super-tab";
          "<A-y>".__raw = "require('minuet').make_blink_map()";
        };
        completion = {
          documentation.auto_show = true;
          trigger.prefetch_on_insert = false;
          menu = {
            draw = {
              treesitter = { "lsp" = [ "kind" ]; };
            };
          };
        };
        appearance.nerd_font_variant = "normal";
        signature.enabled = true;
        cmdline.enabled = true;
        fuzzy.implementation = "prefer_rust_with_warning";
        sources = {
          default = [ "lsp" "path" "buffer" "snippets" "minuet" ];
          per_filetype = { };
          providers = {
            minuet = {
              name = "minuet";
              module = "minuet.blink";
              async = true;
              timeout_ms = 3000;
              score_offset = 50;
            };
          };
        };
      };
    };
  };
}
