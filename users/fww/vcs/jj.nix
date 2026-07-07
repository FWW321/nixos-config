# filepath: ~/nixos-config/users/fww/vcs/jj.nix
# Jujutsu (jj) - Git 兼容现代 VCS
# 用 HM 26.05+ 原生 programs.jujutsu module(settings attrset → 自动生成 config.toml)
# jj 不读 git config,需独立配 user/editor;ssh 仍走 ~/.ssh/config 共用
# delta:复用 git 侧 delta(delta 启动时读 git config [delta] 段渲染,样式自动一致)
# 补全:已全局开 carapace + nushell 集成(terminal.nix),装上即自动有 jj 补全
{ common }:
{ ... }:
{
  programs.jujutsu = {
    enable = true;                  # jujutsu 包由此 module 自动装(watchman/delta 由 default.nix 统一装)
    settings = {
      user = {
        name = common.name;
        email = common.email;
      };
      ui = {
        default-command = "log";    # 裸 `jj` 显示 log(默认是 help)
        editor = common.editor;     # jj 不读 git core.editor,独立设
        pager = "delta";            # 复用 git 侧 delta(读 ~/.gitconfig [delta] 段渲染)
      };
      git = {
        auto-local-bookmark = true; # fetch 远程分支时自动建本地 bookmark
        push-bookmark = "main";     # jj git push 默认推 main
      };
      core.fsmonitor = "watchman";  # watchman 监控文件变更,大仓库加速 status/diff
      signing = {
        behavior = "own";           # 自动签自己创建的 commit(不动远程拉取的)
        backend = "ssh";
        key = common.signingKey;    # 签名公钥路径(与 git 同一把 ssh key)
      };
      # 编辑器写 commit 时附带 diff,写 message 有上下文(社区标配)
      templates.draft_commit_description = ''
        concat(
          builtin_draft_commit_description,
          "\nJJ: ignore-rest\n",
          diff.git(),
        )
      '';
      revset-aliases = {
        HEAD = "@";
        "mine()" = "author(\"${common.email}\")"; # jj log -r 'mine()' 查自己提交
      };
    };
  };
}
