# filepath: ~/nixos-config/modules/user/editor/git.nix
# Git 增强显示与操作（gitsigns v2.0）
{ ... }:

{
  programs.nixvim.plugins.gitsigns = {
    enable = true;
    settings = {
      signs_staged.enable = true;
      current_line_blame = true;
      current_line_blame_opts = {
        virt_text = true;
        virt_text_pos = "eol";
        delay = 500;
      };
      on_attach = ''
        function(_, bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map("n", "<leader>gh", gs.preview_hunk_inline, "预览修改")
          map("n", "<leader>gb", gs.blame_line, "Git Blame")
          map("n", "<leader>ga", gs.stage_hunk, "Stage Hunk")
          map("n", "<leader>gr", gs.reset_hunk, "取消暂存")
          map("n", "<leader>gS", gs.stage_buffer, "暂存整个文件")
          map("n", "<leader>gu", gs.undo_stage_hunk, "撤销暂存")
          map("n", "]h", gs.next_hunk, "下一个修改")
          map("n", "[h", gs.prev_hunk, "上一个修改")
        end
      '';
    };
  };
}
