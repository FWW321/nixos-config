{ pkgs, inputs, ... }:

{
  rtk = {
    package = pkgs.rtk;
    source = inputs.rtk;
  };
  herdr = {
    source = inputs.herdr;
  };
  # dcg (Destructive Command Guard):拦截 AI agent 破坏性 bash 命令的安全护栏
  # 环境无关 → 落 plugins.nix(defaultEnabled=true),不走 -project 二分
  # 同 rtk 形状{package, source}:二进制和 opencode adapter plugin 同 derivation 产出
  # → source 指向 package 自身的 $out/share/opencode-plugins(pkgs/dcg 的 postInstall 装入)
  # → agents/opencode.nix 用 "${source}/dcg-guard.js" 写 xdg.configFile
  dcg = {
    package = pkgs.dcg;
    source = "${pkgs.dcg}/share/opencode-plugins";
  };
}
