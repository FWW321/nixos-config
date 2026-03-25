# filepath: ~/nixos-config/modules/user/editor/treesitter.nix
# 语法高亮、缩进、折叠、增量选择、文本对象
{
  pkgs,
  ...
}:

{
  programs.nixvim.plugins = {
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        folding.enable = true;
        incremental_selection = {
          enable = true;
          keymaps = {
            init_selection = "<C-space>";
            node_incremental = "<C-space>";
            scope_incremental = false;
            node_decremental = "<bs>";
          };
        };
      };
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        # 系统配置
        nix
        bash
        # Lua / Vim
        lua
        luadoc
        vim
        vimdoc
        # C/C++
        c
        cpp
        # 系统编程
        rust
        zig
        go
        gomod
        # JVM
        java
        # Python
        python
        # Web
        javascript
        typescript
        tsx
        html
        css
        scss
        vue
        svelte
        graphql
        # 数据格式
        json
        json5
        yaml
        toml
        # 文档
        markdown
        markdown_inline
        # DevOps / 配置
        dockerfile
        proto
        cmake
        make
        just
        helm
        # 其他
        regex
        sql
        http
        diff
        gitcommit
        query
      ];
    };
    treesitter-textobjects = {
      enable = true;
      settings = {
        select = {
          enable = true;
          lookahead = true;
          keymaps = {
            af = "@function.outer";
            "if" = "@function.inner";
            ac = "@class.outer";
            ic = "@class.inner";
            aC = "@conditional.outer";
            iC = "@conditional.inner";
            ab = "@block.outer";
            ib = "@block.inner";
            al = "@loop.outer";
            il = "@loop.inner";
            ap = "@parameter.outer";
            ip = "@parameter.inner";
          };
        };
        move = {
          enable = true;
          goto_next_start = {
            "]f" = "@function.outer";
            "]c" = "@class.outer";
            "]b" = "@block.outer";
            "]l" = "@loop.outer";
            "]p" = "@parameter.outer";
          };
          goto_next_end = {
            "]F" = "@function.outer";
            "]C" = "@class.outer";
          };
          goto_previous_start = {
            "[f" = "@function.outer";
            "[c" = "@class.outer";
            "[b" = "@block.outer";
            "[l" = "@loop.outer";
            "[p" = "@parameter.outer";
          };
          goto_previous_end = {
            "[F" = "@function.outer";
            "[C" = "@class.outer";
          };
        };
        swap = {
          enable = true;
          swap_next = {
            "<leader>sp" = "@parameter.inner";
          };
          swap_previous = {
            "<leader>sP" = "@parameter.inner";
          };
        };
      };
    };
  };
}
