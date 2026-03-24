# filepath: ~/nixos-config/modules/user/desktop/nautilus.nix
# Nautilus 文件管理器 - 最佳配置
{ pkgs, ... }:

{
  # 安装 Nautilus 和相关工具
  home.packages = with pkgs; [
    nautilus
    sushi
    loupe
    mpv
    celluloid
    file-roller
    gnome-disk-utility
    gvfs
  ];

  # 设置为默认文件管理器
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/x-directory" = "org.gnome.Nautilus.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/avif" = "org.gnome.Loupe.desktop";
      "image/heic" = "org.gnome.Loupe.desktop";
      "image/heif" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "video/mp4" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-matroska" = "io.github.celluloid_player.Celluloid.desktop";
      "video/webm" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-msvideo" = "io.github.celluloid_player.Celluloid.desktop";
      "video/quicktime" = "io.github.celluloid_player.Celluloid.desktop";
      "audio/mpeg" = "io.github.celluloid_player.Celluloid.desktop";
      "audio/flac" = "io.github.celluloid_player.Celluloid.desktop";
      "audio/x-wav" = "io.github.celluloid_player.Celluloid.desktop";
      "audio/ogg" = "io.github.celluloid_player.Celluloid.desktop";
      "audio/mp4" = "io.github.celluloid_player.Celluloid.desktop";
    };
  };

  # Nautilus 配置（通过 dconf）
  dconf.settings = {
    # 主要设置
    "org/gnome/nautilus/preferences" = {
      # 默认视图：列表视图（更信息丰富）
      default-folder-viewer = "list-view";

      # 显示隐藏文件（开发者友好）
      show-hidden-files = true;

      # 搜索过滤器：按修改时间
      search-filter-time-type = "last_modified";

      # 可执行文本文件：询问（安全）
      executable-text-activation = "ask";

      # 侧边栏显示删除文件夹（回收站）
      show-delete-permanently = true;

      # 文件排序：文件夹优先
      show-directory-item-counts = "always";

      # 创建链接时使用相对路径
      show-create-link = true;
    };

    # 列表视图设置
    "org/gnome/nautilus/list-view" = {
      # 启用树状视图（可展开文件夹）
      use-tree-view = true;

      # 默认显示列
      default-visible-columns = [ "name" "size" "type" "date_modified" ];

      # 默认列顺序
      default-column-order = [
        "name"
        "size"
        "type"
        "date_modified"
        "date_accessed"
        "owner"
        "group"
        "permissions"
      ];

      # 默认缩放级别
      default-zoom-level = "standard";
    };

    # 图标视图设置
    "org/gnome/nautilus/icon-view" = {
      # 默认缩放级别
      default-zoom-level = "standard";

      # 图标说明文字（显示文件大小和类型）
      captions = [ "size" "type" "none" ];
    };

    # 窗口状态
    "org/gnome/nautilus/window-state" = {
      # 启动时最大化
      maximized = false;

      # 侧边栏宽度
      sidebar-width = 200;

      # 默认窗口大小
      initial-size = [
        1000
        600
      ];
    };

    # 压缩设置
    "org/gnome/nautilus/compression" = {
      # 默认压缩格式：zip（兼容性好）
      default-compression-format = "zip";
    };
  };

}
