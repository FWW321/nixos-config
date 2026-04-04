# filepath: ~/nixos-config/modules/user/editor/default.nix
# Neovim 编辑器入口：全局选项、外部依赖、子模块汇总
{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./ui.nix
    ./completion.nix
    ./treesitter.nix
    ./lsp.nix
    ./git.nix
    ./snacks.nix
    ./plugins.nix
    ./keymaps.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    performance.byteCompileLua.enable = true;

    extraPackages = with pkgs; [
      # 搜索工具（snacks picker / grepprg 必需）
      ripgrep
      fd
      # Nix
      nixfmt
      statix
      # Git
      lazygit
      # Node.js（copilot.lua 需要）
      nodejs
      # Rust
      cargo
      rustc
      rustfmt
      # Python
      ruff
      # Lua
      stylua
      # Go
      go
      golangci-lint
      # Java
      google-java-format
      # Zig
      zig
      # C/C++
      clang-tools
      # Web
      prettier
      prettierd
      # Shell
      shfmt
      shellcheck
      # Lint
      markdownlint-cli
      yamllint
      eslint_d
      # TOML
      taplo
      # 其他
      jq
    ];

    globals.mapleader = " ";

    opts = {
      # 行号与缩进
      number = true;
      relativenumber = true;
      shiftwidth = 4;
      tabstop = 4;
      expandtab = true;
      autoindent = true;
      shiftround = true;

      # 搜索
      ignorecase = true;
      smartcase = true;
      inccommand = "nosplit";

      # 光标与视图
      cursorline = true;
      scrolloff = 8;
      sidescrolloff = 8;
      wrap = false;
      linebreak = true;

      # 编辑行为
      clipboard = "unnamedplus";
      mouse = "a";
      confirm = true;
      undofile = true;
      undolevels = 10000;
      virtualedit = "block";

      # 折叠（配合 treesitter folding）
      foldlevel = 99;
      foldtext = "";

      # 分屏
      splitbelow = true;
      splitright = true;
      splitkeep = "screen";
      winminwidth = 5;

      # 界面布局
      showtabline = 2;
      laststatus = 3;
      cmdheight = 1;
      ruler = false;
      showmode = false;
      pumheight = 10;
      pumblend = 10;
      conceallevel = 2;

      # 补全（Neovim 0.11 原生模糊匹配）
      completeopt = "menu,menuone,noselect,fuzzy";

      # 滚动
      smoothscroll = true;

      # 列
      signcolumn = "yes";

      # 事件
      updatetime = 200;
      timeoutlen = 300;

      # 美化填充字符
      fillchars = "vert:│,fold: ,foldopen:▾,foldsep: ,foldclose:▸,diff:╱,eob: ";

      # 格式选项（LazyVim 标准）
      formatoptions = "jcroqlnt";

      # 搜索工具
      grepprg = "rg --vimgrep";

      # 补全提示
      shortmess = "filnxtToOFI";

      # 命令行补全
      wildmode = "longest:full,full";

      # 会话
      sessionoptions = "buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds";
    };
  };
}
