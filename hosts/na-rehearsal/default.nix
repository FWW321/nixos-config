# filepath: ~/nixos-config/hosts/na-rehearsal/default.nix
# NA 装机彩排夹具主机 —— install.sh --fixture 端到端验证目标:
#   QEMU(-nographic 串口)+ OVMF + 彩排 ISO(root 预置一次性公钥)→
#   ./install.sh na-rehearsal <目标> --fixture
# 夹具语义:secrets 自含(引用 vmtest 的 fixture 对,单一真源)、facter 为
# 不变量(彩排时不重采集)、dae/smartd 关(彩排环境无对应硬件)。
# 装完验证走串口登录(模块层 sshd 禁密码,fixture 密码仅控制台可用)
{
  lib,
  inputs,
  ...
}:

let
  p = import ./params.nix;
in
{
  imports = [
    ./disko.nix
  ]
  ++ lib.optionals (p.gpu == "nvidia") [ ./nvidia.nix ]
  ++ [
    inputs.nixos-hardware.nixosModules.${p.cpuProfile}
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  hardware.facter.reportPath = ./.facter.json;

  # ── 彩排环境裁剪 ─────────────────────────────────────
  services.dae.enable = lib.mkForce false; # 无代理网络,免 crashloop
  services.smartd.enable = lib.mkForce false; # virtio 盘无 SMART
  # -nographic 串口全链路可观测(内核日志 + 登录提示符都在 ttyS0)
  boot.kernelParams = lib.mkAfter [ "console=ttyS0,115200n8" ];

  # sops 夹具:与 vmtest 共用同一对 fixture 文件(维护契约见 vmtest 头注)
  sops = {
    defaultSopsFile = lib.mkForce ../vmtest/secrets-fixture.yaml;
    age.sshKeyPaths = lib.mkForce [ ]; # 无 host key,钥匙经 /etc 转交
    age.keyFile = lib.mkForce "/etc/sops-fixture-age-key";
  };
  environment.etc."sops-fixture-age-key".text = builtins.readFile ../vmtest/age-key-fixture.txt;

  system.stateVersion = "26.05";
}
