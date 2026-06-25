# filepath: ~/nixos-config/users/fww/games.nix
# 游戏环境：游戏启动器与游戏相关工具
{
  pkgs,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      # ── Minecraft ──
      modrinth-app # Modrinth 启动器（Tauri/WebKit），自动管理 Java 与游戏下载
    ];
}
