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
      # Modrinth 启动器（Tauri/WebKit），自动管理 Java 与游戏下载
      # 数据目录结构：
      #   ~/.local/share/ModrinthApp/
      #   ├── profiles/<实例名>/      # 每个实例 = 一个独立 .minecraft
      #   │   ├── mods/               # 模组
      #   │   ├── saves/              # 存档
      #   │   ├── resourcepacks/      # 材质包
      #   │   ├── shaderpacks/        # 光影包
      #   │   └── datapacks/          # 数据包
      #   ├── meta/                   # 跨实例共享（省空间，复用）
      #   │   ├── java_versions/      # Java 运行时
      #   │   ├── versions/           # 原版游戏本体 client.jar（按版本）
      #   │   ├── libraries/          # 游戏依赖库 + 加载器（Fabric loader 的 jar）
      #   │   ├── assets/             # 音效/贴图等资源
      #   │   └── natives/            # native 库
      #   ├── app.db                  # 实例元数据/设置/已装 mod 列表（SQLite）
      #   └── WebKitCache/, CacheStorage/  # Tauri/WebKit 的 UI 缓存
      modrinth-app
    ];
}
