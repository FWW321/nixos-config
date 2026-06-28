# filepath: ~/nixos-config/modules/user/desktop/media.nix
# 媒体查看器：图片 / 视频播放
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swayimg
    mpv
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png" = "swayimg.desktop";
      "image/jpeg" = "swayimg.desktop";
      "image/webp" = "swayimg.desktop";
      "image/gif" = "swayimg.desktop";
      "image/avif" = "swayimg.desktop";
      "image/heic" = "swayimg.desktop";
      "image/heif" = "swayimg.desktop";
      "image/svg+xml" = "swayimg.desktop";
      "image/bmp" = "swayimg.desktop";
      "image/tiff" = "swayimg.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop";
      "audio/flac" = "mpv.desktop";
      "audio/x-wav" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "audio/mp4" = "mpv.desktop";
    };
  };
}
