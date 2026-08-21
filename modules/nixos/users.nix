# filepath: ~/nixos-config/modules/nixos/users.nix
# 用户、组、权限、tmpfiles 规则
{ config, pkgs, ... }:

{
  users.groups.shared = { };

  users.users.fww = {
    isNormalUser = true;
    # 首启即建家目录:真机上它此前由 install.sh 拷仓库那步顺手创建(潜伏依赖),
    # VM 装机验证暴露 —— 若跳过拷贝,全新机器 HM 首启会 cd /home/fww 失败
    createHome = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "shared"
      "kvm"
    ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    shell = pkgs.brush;
  };

  # 目录=tmpfiles 创建(非 shell mkdir):时序由 systemd 保证(tmpfiles-setup
  # After=local-fs、Before=sysinit),fww 家目录必须在此建 —— activation 的
  # createHome 跑在 stage-2(早于 systemd 挂载 /home),目录会建在 @root 上被
  # @home 子卷/独立盘挂载遮蔽(VM 装机验证实测;真机此前靠 install.sh 拷仓库
  # 顺手建目录掩盖了这点,跳过拷贝的全新机器 HM 首启必炸 cd /home/fww)
  systemd.tmpfiles.rules = [
    "d /home/fww 0700 fww users - -"
    "d /data/public 2775 root shared - -"
    "d /data/public/games 2775 root shared - -"
    "d /data/public/games/steam 2775 root shared - -"
    "d /data/public/music 2775 root shared - -"
    "d /data/public/videos 2775 root shared - -"
    "d /data/public/pictures 2775 root shared - -"
    "d /data/private 0755 root root - -"
    "d /data/private/fww 0700 fww users - -"
  ];

  # sudo 配置
  security.sudo.extraConfig = "Defaults lecture = never";
  security.polkit.enable = true;

  # 注册 shell 到 /etc/shells（pkexec 需要）
  environment.shells = with pkgs; [
    brush
    bash
  ];
}
