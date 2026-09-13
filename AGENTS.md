# AGENTS.md — 本仓操作纪律

全局纪律(改前 Read 原文 / 增量 Edit / 相对路径)见环境注入的 AGENTS.md;
本文件只补本仓特有部分。以下纪律均有事故出处,不是风格偏好。

## flake 锁纪律

- `sources/flake.nix` 加/删 pin 后,必须 `nix flake update sources/<name>` 同步锁。
  该命令只动目标条目并补齐缺失引用,其余不碰
- **禁**裸跑 `nix flake lock` 与 `nix flake update sources`(全表):登记表 8 个
  未钉 ref 的 pin 会被整体刷到上游 HEAD ——"加一个 pin,九个跟着变"
- 提交锁前 `git diff flake.lock`:sources 节点应只有预期条目的变化,
  主输入(nixpkgs/home-manager/…)rev 一个不许动
- ⚠ **验锁必须读 root inputs 指向的节点**:本仓锁的顶层 `nixpkgs` 是
  无主孤儿(某 flake 的传递依赖,ref 钉 unstable-small 且随解析漂移);
  本尊是 `nixpkgs_3`(root inputs → nixpkgs_3)。读错节点会得出
  "锁更新丢了"的假结论,2026-09-13 实测为此空耗半小时并险些回滚
  好锁。验尸姿势:

      jq '.nodes[.nodes[root].inputs.nixpkgs // "nixpkgs"].locked.rev' flake.lock

- ⚠ 验证/求值引用一律用 `.#`(path 形态);`builtins.getFlake
  "git+file://…"` 会连孤儿/传递节点一起全量刷锁(2026-09-13 实测
  22 个 rev 被刷,靠 git checkout 才拦住)
- ⚠ 锁与 flake.nix 不一致时,`nix eval` 会**静默重写 flake.lock**(修剪 root
  inputs、GC 孤儿节点)。诊断结束后必查 `git status`;出现来历不明的锁改动,
  用 `git diff flake.lock` 对质,不要先怀疑 nix
- 锁脱节的症状是求值时 `attribute '...' missing` 而非锁错误本身;
  遇 missing 先怀疑锁脱节,再查代码

## 提交纪律

- 小步提交,禁长寿命脏树:2026-09-03~13 的 45 文件未提交曾让 CI 质量门
  整体旁路 10 天,锁脱节混在其中无人察觉
- 每个提交点保持可求值。验证用 worktree,勿用 stash:

      git worktree add /tmp/ct <commit>
      cd /tmp/ct && nix eval .#nixosConfigurations.FWW-Desktop.config.system.build.toplevel.drvPath

  (stash 的 pop 失败会被吞在管道里,2026-09-13 实测 40 分钟后才发现)
- 同文件多主题拆 hunks:临时构造中间态(改文件 → add → 恢复)优于交互式 add -p

## agent / skill 变更

- `common/skills.nix` 变更生效 = rebuild + `opencode2 service restart`
  (skill 注册表是服务启动快照,无热注册 API,见该文件头注释)

## 调试纪律

- 不吞 stderr:禁止 `>/dev/null 2>&1`。要截断输出用 `2>&1 | tail`,
  关键错误行不许丢

## hooks 与本地预演

- 启用锁探针(一次性,clone 后执行):
  `git config core.hooksPath .githooks`
  —— 提交触及 flake.nix / sources/flake.nix / flake.lock 时自动跑单主机求值,
  把锁脱节拦在 commit 前
- push 前本地预演 CI:`nix run .#ci-local`
