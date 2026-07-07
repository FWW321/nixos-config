# filepath: ~/nixos-config/users/fww/editors/nvim/lsp.nix
# LSP 语言服务器、诊断（nvim-lint）、格式化（conform-nvim）
{
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
      inlayHints = false;
      onAttach = ''
        if client:supports_method("textDocument/inlayHint") then
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          vim.b[bufnr].inlay_hint_refresh_count = 0
        end
      '';
      servers = {
        nixd.enable = true;

        rust_analyzer = {
          enable = true;
          installCargo = false;
          installRustc = false;
          settings = {
            inlayHints = {
              enable = true;
              typeHints.enable = true;
              parameterHints.enable = true;
              chainingHints.enable = true;
              closureReturnTypeHints.enable = true;
            };
            cargo = {
              # rust-analyzer 用独立 target 目录，避免与终端里的 cargo build/run 抢 .package-cache 锁
              targetDir = true;
            };
            # 保存时跑 cargo check（默认行为）：比 clippy 轻很多，只有 borrow checker 无 lint。
            # 配合 cargo.targetDir 隔离 + rust-analyzer 内部 coalesce，auto-save 下也不会卡。
            # 需要 lint 时在终端手动 cargo clippy。
            check = {
              command = "check";
              onSave = true;
            };
          };
        };

        lua_ls = {
          enable = true;
          settings = {
            diagnostics.globals = [ "vim" ];
            workspace.library = [
              "\${3rd}/luv/library"
              "\${3rd}/busted/library"
            ];
            telemetry.enable = false;
            hint = {
              enable = true;
              setType = true;
              paramType = true;
              paramName = "all";
              arrayIndex = "Auto";
            };
            format = {
              enable = true;
              defaultConfig = {
                indent_style = "space";
                indent_size = 2;
              };
            };
          };
        };

        basedpyright = {
          enable = true;
          settings = {
            basedpyright = {
              analysis = {
                inlayHints = {
                  variableTypes = true;
                  callArgumentNames = true;
                  functionReturnTypes = true;
                  genericTypes = true;
                };
              };
            };
          };
        };
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
              inlayHints = {
                parameterNames = {
                  enabled = "all";
                  suppressWhenArgumentMatchesName = true;
                };
                functionLikeReturnTypes = {
                  enabled = true;
                };
                variableTypes = {
                  enabled = true;
                };
                propertyDeclarationTypes = {
                  enabled = true;
                };
                enumMemberValues = {
                  enabled = true;
                };
              };
            };
            javascript = {
              inlayHints = {
                parameterNames = {
                  enabled = "all";
                  suppressWhenArgumentMatchesName = true;
                };
                functionLikeReturnTypes = {
                  enabled = true;
                };
                variableTypes = {
                  enabled = true;
                };
                propertyDeclarationTypes = {
                  enabled = true;
                };
                enumMemberValues = {
                  enabled = true;
                };
              };
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
        svelte.enable = true;
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

        asm_lsp = {
          enable = true;
          filetypes = [ "asm" "nasm" "fasm" "s" "S" ];
        };
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
          "<leader>cd" = {
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

    # Lean 4：原生 lean.nvim 包装（LSP 连接 + infoview 证明目标面板 + 缩写 + 高亮）
    # lean.nvim 自管 LSP，勿另开 servers.leanls（会重复 attach）
    lean = {
      enable = true;
      settings.mappings = true;
    };

    lint = {
      enable = true;
      lintersByFt = {
        nix = [ "statix" ];
        bash = [ "shellcheck" ];
        sh = [ "shellcheck" ];
        markdown = [ "markdownlint" ];
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
        # auto-save.nvim README 推荐：合并格式化与编辑到同一 undo 步骤
        # 使 undo 一次性撤销「编辑 + 自动格式化」
        undojoin = true;
        notify_on_error = false;
        formatters_by_ft = {
          nix = [ "nixfmt" ];
          lua = [ "stylua" ];
          python = [
            "ruff_format"
            "ruff_fix"
          ];
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
          nasm = [ "nasmfmt" ];
          toml = [ "taplo" ];
          graphql = [ "prettier" ];
          jq = [ "jq" ];
          "_" = [
            "trim_whitespace"
            "trim_newlines"
          ];
        };
        formatters = {
          shfmt = {
            prepend_args = [
              "-i"
              "4"
              "-ci"
            ];
          };
          google-java-format = {
            prepend_args = [ "--aosp" ];
          };
          nasmfmt = {
            args = [ "-" ];
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
