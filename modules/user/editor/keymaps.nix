# filepath: ~/nixos-config/modules/user/editor/keymaps.nix
# 全局按键映射（LazyVim 风格命名空间）
{ ... }:

{
  programs.nixvim.plugins.keymaps = [
    # --- Buffer ---
    {
      mode = "n";
      key = "<leader>bd";
      action = "<cmd>bdelete<CR>";
      options.desc = "Delete Buffer";
    }
    {
      mode = "n";
      key = "<leader>bb";
      action = "<cmd>e #<CR>";
      options.desc = "Alternate Buffer";
    }
    {
      mode = "n";
      key = "<leader>bo";
      action = "<cmd>%bd|e#|bd#<CR>";
      options.desc = "Delete Other Buffers";
    }

    # --- Code ---
    {
      mode = "n";
      key = "<leader>cf";
      action = "<cmd>Format<CR>";
      options.desc = "Format Code";
    }

    # --- 查找 ---
    {
      mode = "n";
      key = "<leader><space>";
      action.__raw = "function() Snacks.picker.smart() end";
      options.desc = "Smart Find";
    }
    {
      mode = "n";
      key = "<leader>ff";
      action.__raw = "function() Snacks.picker.files() end";
      options.desc = "Find Files";
    }
    {
      mode = "n";
      key = "<leader>fg";
      action.__raw = "function() Snacks.picker.grep() end";
      options.desc = "Live Grep";
    }
    {
      mode = "n";
      key = "<leader>/";
      action.__raw = "function() Snacks.picker.grep() end";
      options.desc = "Grep";
    }
    {
      mode = "n";
      key = "<leader>fb";
      action.__raw = "function() Snacks.picker.buffers() end";
      options.desc = "Buffers";
    }
    {
      mode = "n";
      key = "<leader>fo";
      action.__raw = "function() Snacks.picker.recent() end";
      options.desc = "Recent Files";
    }
    {
      mode = "n";
      key = "<leader>fw";
      action.__raw = "function() Snacks.picker.grep_word() end";
      options.desc = "Grep Word";
    }
    {
      mode = "n";
      key = "<leader>fc";
      action.__raw =
        "function() Snacks.picker.files({ cwd = vim.fn.stdpath('config') }) end";
      options.desc = "Find Config File";
    }
    {
      mode = "n";
      key = "<leader>fd";
      action.__raw = "function() Snacks.picker.diagnostics() end";
      options.desc = "Diagnostics";
    }
    {
      mode = "n";
      key = "<leader>fh";
      action.__raw = "function() Snacks.picker.help() end";
      options.desc = "Help Pages";
    }
    {
      mode = "n";
      key = "<leader>fM";
      action.__raw = "function() Snacks.picker.man() end";
      options.desc = "Man Pages";
    }
    {
      mode = "n";
      key = "<leader>fk";
      action.__raw = "function() Snacks.picker.keymaps() end";
      options.desc = "Keymaps";
    }
    {
      mode = "n";
      key = "<leader>fp";
      action.__raw = "function() Snacks.picker.projects() end";
      options.desc = "Projects";
    }

    # --- Toggle ---
    {
      mode = "n";
      key = "<leader>tt";
      action.__raw = "function() Snacks.terminal() end";
      options.desc = "Toggle Terminal";
    }
    {
      mode = "n";
      key = "<leader>tT";
      action.__raw =
        "function() Snacks.terminal({ cwd = vim.fn.expand('%:p:h') }) end";
      options.desc = "Terminal (cwd)";
    }

    # --- Git ---
    {
      mode = "n";
      key = "<leader>gg";
      action.__raw = "function() Snacks.lazygit.open() end";
      options.desc = "Lazygit";
    }
    {
      mode = "n";
      key = "<leader>gs";
      action.__raw = "function() Snacks.picker.git_status() end";
      options.desc = "Git Status";
    }
    {
      mode = "n";
      key = "<leader>gB";
      action.__raw = "function() Snacks.picker.git_branches() end";
      options.desc = "Git Branches";
    }
    {
      mode = "n";
      key = "<leader>gl";
      action.__raw = "function() Snacks.picker.git_log() end";
      options.desc = "Git Log";
    }
    {
      mode = "n";
      key = "<leader>go";
      action.__raw = "function() Snacks.gitbrowse() end";
      options.desc = "Git Browse";
    }

    # --- LSP（snacks picker 增强） ---
    {
      mode = "n";
      key = "gd";
      action.__raw = "function() Snacks.picker.lsp_definitions() end";
      options.desc = "Goto Definition";
    }
    {
      mode = "n";
      key = "gI";
      action.__raw = "function() Snacks.picker.lsp_implementations() end";
      options.desc = "Goto Implementation";
    }
    {
      mode = "n";
      key = "gy";
      action.__raw = "function() Snacks.picker.lsp_type_definitions() end";
      options.desc = "Goto Type Definition";
    }
    {
      mode = "n";
      key = "gr";
      action.__raw = "function() Snacks.picker.lsp_references() end";
      options.desc = "References";
    }

    # --- 搜索 ---
    {
      mode = "n";
      key = "<leader>su";
      action.__raw = "function() Snacks.picker.undo() end";
      options.desc = "Undo History";
    }
    {
      mode = "n";
      key = "<leader>sn";
      action.__raw = "function() Snacks.picker.notifications() end";
      options.desc = "Notifications";
    }
    {
      mode = "n";
      key = "<leader>st";
      action = "<cmd>TodoQuickFix<CR>";
      options.desc = "TODO List";
    }
    {
      mode = "n";
      key = "<leader>sT";
      action.__raw = "function() Snacks.picker.todo_comments() end";
      options.desc = "TODO Search";
    }
    {
      mode = "n";
      key = "<leader>sR";
      action.__raw = "function() Snacks.picker.resume() end";
      options.desc = "Resume Picker";
    }

    # --- Trouble ---
    {
      mode = "n";
      key = "<leader>xx";
      action = "<cmd>Trouble diagnostics toggle<CR>";
      options.desc = "Diagnostics";
    }
    {
      mode = "n";
      key = "<leader>xX";
      action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
      options.desc = "Buffer Diagnostics";
    }
    {
      mode = "n";
      key = "<leader>xq";
      action = "<cmd>Trouble qflist toggle<CR>";
      options.desc = "Quickfix";
    }
    {
      mode = "n";
      key = "<leader>xl";
      action = "<cmd>Trouble loclist toggle<CR>";
      options.desc = "Location List";
    }
    {
      mode = "n";
      key = "<leader>xs";
      action = "<cmd>Trouble symbols toggle<CR>";
      options.desc = "Symbols";
    }

    # --- 文件导航 ---
    {
      mode = "n";
      key = "<leader>e";
      action.__raw = "function() Snacks.explorer() end";
      options.desc = "Explorer";
    }
    {
      mode = "n";
      key = "<leader>E";
      action.__raw =
        "function() Snacks.explorer({ cwd = vim.fn.expand('%:p:h') }) end";
      options.desc = "Explorer (cwd)";
    }

    # --- UI 切换 ---
    {
      mode = "n";
      key = "<leader>uz";
      action.__raw = "function() Snacks.zen() end";
      options.desc = "Zen Mode";
    }

    # --- 窗口 ---
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "左侧分屏";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "右侧分屏";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "下方分屏";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "上方分屏";
    }
    {
      mode = "n";
      key = "<leader>-";
      action = "<C-w>s";
      options.desc = "水平分屏";
    }
    {
      mode = "n";
      key = "<leader>|";
      action = "<C-w>v";
      options.desc = "垂直分屏";
    }
    {
      mode = "n";
      key = "<leader>wd";
      action = "<C-w>c";
      options.desc = "关闭窗口";
    }
    {
      mode = "n";
      key = "<leader>wm";
      action = "<C-w>|<C-w>_";
      options.desc = "最大化窗口";
    }
    {
      mode = "n";
      key = "<leader>w=";
      action = "<C-w>=";
      options.desc = "等分窗口";
    }

    # --- Buffer 切换 ---
    {
      mode = "n";
      key = "<S-h>";
      action = "<cmd>bprevious<CR>";
      options.desc = "Prev Buffer";
    }
    {
      mode = "n";
      key = "<S-l>";
      action = "<cmd>bnext<CR>";
      options.desc = "Next Buffer";
    }

    # --- 通用 ---
    {
      mode = "n";
      key = "<C-s>";
      action = "<cmd>w<CR>";
      options.desc = "Save";
    }
    {
      mode = "n";
      key = "<leader>q";
      action = "<cmd>q<CR>";
      options.desc = "Quit";
    }
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
      options.desc = "清除高亮";
    }

    # --- 插入模式 ---
    {
      mode = "i";
      key = "jk";
      action = "<Esc>";
      options.desc = "退出插入模式";
    }
    {
      mode = "i";
      key = "<C-a>";
      action = "<Home>";
      options.desc = "行首";
    }
    {
      mode = "i";
      key = "<C-e>";
      action = "<End>";
      options.desc = "行尾";
    }

    # --- AI (opencode) ---
    {
      mode = [ "n" "x" ];
      key = "<leader>aa";
      action.__raw = "function() require('opencode').ask('@this: ', { submit = true }) end";
      options.desc = "Ask opencode";
    }
    {
      mode = [ "n" "x" ];
      key = "<leader>ax";
      action.__raw = "function() require('opencode').select() end";
      options.desc = "opencode Actions";
    }
    {
      mode = [ "n" "t" ];
      key = "<leader>at";
      action.__raw = "function() require('opencode').toggle() end";
      options.desc = "Toggle opencode";
    }
    {
      mode = "n";
      key = "<leader>ae";
      action.__raw = ''
        function() require('opencode').prompt('explain') end
      '';
      options.desc = "Explain";
    }
    {
      mode = "n";
      key = "<leader>ar";
      action.__raw = ''
        function() require('opencode').prompt('review') end
      '';
      options.desc = "Review";
    }
    {
      mode = "n";
      key = "<leader>af";
      action.__raw = ''
        function() require('opencode').prompt('fix') end
      '';
      options.desc = "Fix Diagnostics";
    }
    {
      mode = "n";
      key = "<leader>ai";
      action.__raw = ''
        function() require('opencode').prompt('implement') end
      '';
      options.desc = "Implement";
    }
    {
      mode = "n";
      key = "<leader>aT";
      action.__raw = ''
        function() require('opencode').prompt('test') end
      '';
      options.desc = "Add Tests";
    }
    {
      mode = "n";
      key = "<leader>ad";
      action.__raw = ''
        function() require('opencode').prompt('document') end
      '';
      options.desc = "Document";
    }
    {
      mode = "n";
      key = "<leader>ao";
      action.__raw = ''
        function() require('opencode').prompt('optimize') end
      '';
      options.desc = "Optimize";
    }
    {
      mode = "n";
      key = "<leader>ag";
      action.__raw = ''
        function() require('opencode').prompt('diff') end
      '';
      options.desc = "Review Git Diff";
    }
    {
      mode = [ "n" "x" ];
      key = "go";
      action.__raw = "function() return require('opencode').operator('@this ') end";
      options.desc = "opencode Operator";
    }
    {
      mode = "n";
      key = "<C-.>";
      action.__raw = "function() require('opencode').toggle() end";
      options.desc = "Toggle opencode";
    }

    # --- 可视模式 ---
    {
      mode = "v";
      key = "J";
      action = ":m '>+1<CR>gv=gv";
      options.desc = "下移";
    }
    {
      mode = "v";
      key = "K";
      action = ":m '<-2<CR>gv=gv";
      options.desc = "上移";
    }
    {
      mode = "v";
      key = "<";
      action = "<gv";
      options.desc = "左缩进";
    }
    {
      mode = "v";
      key = ">";
      action = ">gv";
      options.desc = "右缩进";
    }
  ];
}
