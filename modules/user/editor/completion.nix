# filepath: ~/nixos-config/modules/user/editor/completion.nix
# 补全引擎（blink-cmp）与 GitHub Copilot AI 补全
{ ... }:

{
  programs.nixvim.plugins = {
    blink-cmp = {
      enable = true;
      settings = {
        keymap.preset = "super-tab";
        completion = {
          documentation.auto_show = true;
          menu = {
            draw = {
              treesitter = { "lsp" = [ "kind" ]; };
            };
          };
        };
        appearance.nerd_font_variant = "normal";
        signature.enabled = true;
        cmdline.enabled = true;
        trigger.prefetch_on_insert = true;
        fuzzy = {
          implementation = "prefer_rust_with_warning";
          use_fzf_lua = false;
        };
        sources = {
          default = [ "lsp" "path" "snippets" "buffer" "copilot" ];
          providers = {
            copilot = {
              name = "Copilot";
              module = "blink-copilot";
              score_offset = 100;
              async = true;
            };
          };
        };
        windows = {
          autocomplete = {
            scrolloff = 4;
            min_width = 40;
          };
          documentation = {
            border = "rounded";
            winhighlight = "Normal:CmpDoc,Border:CmpDocBorder";
          };
          signature_help = {
            border = "rounded";
          };
        };
      };
    };
    copilot-lua = {
      enable = true;
      settings = {
        suggestion.enabled = false;
        panel.enabled = false;
      };
    };
    blink-copilot.enable = true;
  };
}
