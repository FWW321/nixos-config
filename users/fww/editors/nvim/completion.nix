# filepath: ~/nixos-config/users/fww/editors/nvim/completion.nix
# 补全引擎（blink-cmp）
{ ... }:

{
  programs.nixvim.plugins = {
    blink-cmp = {
      enable = true;
      settings = {
        keymap.preset = "super-tab";
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
          default = [ "lsp" "path" "buffer" "snippets" ];
          per_filetype = { };
        };
      };
    };
  };
}
