# filepath: ~/nixos-config/modules/user/desktop/input-method.nix
# Fcitx5 + Rime（雾凇拼音）：声明式输入法配置
{ pkgs, lib, ... }:

let
  fcitx5-rime-with-data = pkgs.fcitx5-rime.override {
    rimeDataPkgs = with pkgs; [
      rime-data
      rime-ice
    ];
  };
in
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [
        fcitx5-rime-with-data
        pkgs.fcitx5-gtk
      ];
      settings = {
        # 中英切换：左 Shift
        globalOptions."Hotkey/TriggerKeys"."0" = "Shift_L";
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";       # 物理键盘布局（QWERTY），非输入法
            DefaultIM = "rime";
          };
          # 仅保留 rime：雾凇拼音内置中英双模式，Shift 切换即可，
          # 无需独立 keyboard-us（默认 IM 即 fallback）
          "Groups/0/Items/0".Name = "rime";
          GroupOrder."0" = "Default";
        };
      };
    };
  };

  systemd.user.services.fcitx5-daemon.Service = {
    Restart = "always";
    RestartSec = "3";
  };

  # 雾凇拼音配置补丁
  xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
    patch:
      schema_list:
        - schema: rime_ice              # 雾凇拼音（全拼）
      # 如需双拼，取消注释以下方案：
      # - schema: double_pinyin_flypy   # 小鹤双拼
      # - schema: double_pinyin_mspy    # 微软双拼
      menu:
        page_size: 7
      ascii_composer:
        switch_key:
          Shift_L: commit_code          # 左 Shift 提交英文
          Shift_R: commit_code          # 右 Shift 同上
          Control_L: noop               # Ctrl 不触发
          Control_R: noop
  '';
}
