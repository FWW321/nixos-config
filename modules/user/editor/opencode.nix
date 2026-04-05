# filepath: ~/nixos-config/modules/user/editor/opencode.nix
# opencode.nvim：AI 编程助手集成（snacks terminal/input/picker 增强）
{ ... }:

{
  programs.nixvim.plugins.opencode = {
    enable = true;

    settings = {
      server = {
        start.__raw = ''
          function()
            require("opencode.terminal").open("opencode --port", {
              split = "right",
              width = math.floor(vim.o.columns * 0.38),
            })
          end
        '';
        stop.__raw = ''
          function()
            require("opencode.terminal").close()
          end
        '';
        toggle.__raw = ''
          function()
            require("opencode.terminal").toggle("opencode --port", {
              split = "right",
              width = math.floor(vim.o.columns * 0.38),
            })
          end
        '';
      };

      prompts = {
        ask = {
          prompt = "";
          ask = true;
          submit = true;
        };
        explain = {
          prompt = "Explain @this and its context";
          submit = true;
        };
        review = {
          prompt = "Review @this for correctness and readability";
          submit = true;
        };
        fix = {
          prompt = "Fix @diagnostics";
          submit = true;
        };
        implement = {
          prompt = "Implement @this";
          submit = true;
        };
        test = {
          prompt = "Add tests for @this";
          submit = true;
        };
        document = {
          prompt = "Add comments documenting @this";
          submit = true;
        };
        optimize = {
          prompt = "Optimize @this for performance and readability";
          submit = true;
        };
        diagnostics = {
          prompt = "Explain @diagnostics";
          submit = true;
        };
        diff = {
          prompt = "Review the following git diff for correctness and readability: @diff";
          submit = true;
        };
      };

      lsp = {
        enabled = true;
        handlers = {
          hover.enabled = true;
          code_action.enabled = true;
        };
      };

      events = {
        enabled = true;
        reload = true;
        permissions = {
          enabled = true;
          idle_delay_ms = 1000;
          edits.enabled = true;
        };
      };
    };
  };

  programs.nixvim.opts.autoread = true;
}
