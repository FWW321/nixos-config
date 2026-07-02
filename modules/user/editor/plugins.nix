# filepath: ~/nixos-config/modules/user/editor/plugins.nix
# 编辑增强、跳转、注释、Trouble、TODO、mini 系列
{ config, pkgs, inputs, ... }:
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

    # 自动保存：okuuva/auto-save.nvim 官方默认 + recommended excludes
    # https://github.com/okuuva/auto-save.nvim
    auto-save = {
      enable = true;
      settings = {
        enabled = true;
        trigger_events = {
          # 官方默认 immediate_save 事件（含 QuitPre / VimSuspend）
          immediate_save = [ "BufLeave" "FocusLost" "QuitPre" "VimSuspend" ];
          defer_save = [ "InsertLeave" "TextChanged" ];
          cancel_deferred_save = [ "InsertEnter" ];
        };
        write_all_buffers = false;
        # README「Combine with formatting」章节官方建议：
        # 设为 true，避免自动保存触发 format_on_save，仅手动 :w 才格式化
        noautocmd = true;
        lockmarks = false;
        debounce_delay = 1000;
        debug = false;
        # README 推荐的 excluded_filetypes（含 gitcommit，避免误保存提交信息）
        # 多数已是 non-modifiable / special-buffer，这里是 "extra safe"
        condition = let
          excluded_filetypes = [
            "gitcommit"
            "NvimTree"
            "Outline"
            "TelescopePrompt"
            "alpha"
            "dashboard"
            "lazygit"
            "neo-tree"
            "oil"
            "prompt"
            "toggleterm"
          ];
          # 生成 Lua 合法的 table 字面量：{ "gitcommit", "NvimTree", ... }
          lua_list = "{ " + builtins.concatStringsSep ", " (map (s: ''"${s}"'') excluded_filetypes) + " }";
        in {
          __raw = ''
            function(buf)
              local excluded_filetypes = ${lua_list}
              if vim.tbl_contains(excluded_filetypes, vim.fn.getbufvar(buf, "&filetype")) then
                return false
              end
              -- 排除 special-buffers（README 示例），buftype 为空才保存
              if vim.fn.getbufvar(buf, "&buftype") ~= "" then
                return false
              end
              return true
            end
          '';
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
      src = inputs.multicursor-nvim;
    })
    pkgs.vimPlugins.plenary-nvim
  ];

  programs.nixvim.extraConfigLua = ''
    require("multicursor-nvim").setup()

    -- auto-save.nvim × snacks.toggle（README「snacks.toggle Integration」官方示例）
    local autosave = require("auto-save")
    require("snacks.toggle").new({
      name = "Auto Save",
      get = function()
        return autosave.enabled()
      end,
      set = function(state)
        if state then
          autosave.on()
        else
          autosave.off()
        end
      end,
    }):map("<leader>ua")

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
