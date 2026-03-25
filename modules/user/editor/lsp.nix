# filepath: ~/nixos-config/modules/user/editor/lsp.nix
# LSP 语言服务器、诊断（nvim-lint）、格式化（conform-nvim）
{
  config,
  pkgs,
  ...
}:

let
  prettierFallback = {
    __unkeyed-1 = "prettierd";
    __unkeyed-2 = "prettier";
    stop_after_first = true;
  };
in
{
  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      servers = {
        nixd.enable = true;

        rust_analyzer = {
          enable = true;
          installCargo = false;
          installRustc = false;
        };

        lua_ls = {
          enable = true;
          settings = {
            diagnostics.globals = [ "vim" ];
            workspace.library = [ "\${3rd}/luv/library" "\${3rd}/busted/library" ];
            telemetry.enable = false;
            format = {
              enable = true;
              defaultConfig = {
                indent_style = "space";
                indent_size = 2;
              };
            };
          };
        };

        basedpyright.enable = true;
        jdtls.enable = true;
        zls.enable = true;
        gopls = {
          enable = true;
          settings = {
            gopls = {
              gofumpt = true;
              codelenses = {
                gc_details = false;
                generate = true;
                regenerate_cgo = true;
                run_govulncheck = true;
                test = true;
                tidy = true;
                upgrade_dependency = true;
                vendor = true;
              };
              hints = {
                assignVariableTypes = true;
                compositeLiteralFields = true;
                compositeLiteralTypes = true;
                constantValues = true;
                functionTypeParameters = true;
                parameterNames = true;
                rangeVariableTypes = true;
              };
              analyses = {
                fieldalignment = true;
                nilness = true;
                unusedparams = true;
                unusedwrite = true;
              };
              staticcheck = true;
            };
          };
        };

        vtsls = {
          enable = true;
          filetypes = [
            "javascript"
            "javascriptreact"
            "typescript"
            "typescriptreact"
            "vue"
          ];
          settings = {
            typescript = {
              tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
              preferences.preferTypeOnlyAutoImports = true;
            };
          };
        };

        clangd = {
          enable = true;
          settings = {
            clangd = {
              fallbackStyle = "llvm";
              InlayHints = {
                Enabled = true;
                ParameterNames = true;
                DeducedTypes = true;
              };
            };
          };
        };

        html.enable = true;
        cssls.enable = true;
        jsonls.enable = true;
        tailwindcss = {
          enable = true;
          filetypes = [
            "html"
            "css"
            "javascript"
            "javascriptreact"
            "typescript"
            "typescriptreact"
            "vue"
            "svelte"
          ];
        };
        yamlls.enable = true;
        taplo.enable = true;
        bashls.enable = true;
        dockerls.enable = true;
        marksman.enable = true;
      };

      keymaps = {
        lspBuf = {
          gD = {
            action = "declaration";
            desc = "Goto Declaration";
          };
          K = {
            action = "hover";
            desc = "Hover";
          };
          "<leader>cr" = {
            action = "rename";
            desc = "Rename Symbol";
          };
          "<leader>ca" = {
            action = "code_action";
            desc = "Code Action";
          };
        };
        diagnostic = {
          "<leader>ld" = {
            action = "open_float";
            desc = "Line Diagnostics";
          };
          "[d" = {
            action = "goto_prev";
            desc = "Prev Diagnostic";
          };
          "]d" = {
            action = "goto_next";
            desc = "Next Diagnostic";
          };
        };
      };
    };

    lint = {
      enable = true;
      lintersByFt = {
        nix = [ "statix" ];
        bash = [ "shellcheck" ];
        sh = [ "shellcheck" ];
        markdown = [ "markdownlint-cli" ];
        yaml = [ "yamllint" ];
        python = [ "ruff" ];
        go = [ "golangci-lint" ];
        javascript = [ "eslint_d" ];
        javascriptreact = [ "eslint_d" ];
        typescript = [ "eslint_d" ];
        typescriptreact = [ "eslint_d" ];
      };
    };

    conform-nvim = {
      enable = true;
      settings = {
        format_on_save = {
          lsp_fallback = true;
          timeout_ms = 1000;
        };
        notify_on_error = false;
        formatters_by_ft = {
          nix = [ "nixfmt" ];
          lua = [ "stylua" ];
          python = [ "ruff_format" "ruff_fix" ];
          rust = [ "rustfmt" ];
          go = [ "gofmt" ];
          java = [ "google-java-format" ];
          zig = [ "zigfmt" ];
          javascript = prettierFallback;
          javascriptreact = prettierFallback;
          typescript = prettierFallback;
          typescriptreact = prettierFallback;
          vue = prettierFallback;
          svelte = prettierFallback;
          html = prettierFallback;
          css = prettierFallback;
          scss = prettierFallback;
          json = prettierFallback;
          json5 = prettierFallback;
          yaml = prettierFallback;
          markdown = prettierFallback;
          bash = [ "shfmt" ];
          sh = [ "shfmt" ];
          c = [ "clang-format" ];
          cpp = [ "clang-format" ];
          proto = [ "buf" ];
          toml = [ "taplo" ];
          graphql = [ "prettier" ];
          jq = [ "jq" ];
          "_" = [ "trim_whitespace" "trim_newlines" ];
        };
        formatters = {
          shfmt = {
            prepend_args = [ "-i" "4" "-ci" ];
          };
          google-java-format = {
            prepend_args = [ "--aosp" ];
          };
        };
      };
    };

    fidget = {
      enable = true;
      settings = {
        progress = {
          poll_rate = 500;
          suppress_on_insert = true;
          ignore_done_already = false;
          ignore_empty_message = true;
        };
        notification = {
          poll_rate = 4000;
          override_vim_notify = true;
        };
      };
    };
  };
}
