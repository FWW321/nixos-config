# filepath: ~/nixos-config/modules/user/terminal.nix
# 终端环境：Foot、Brush、Herdr、现代化 CLI 工具
{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  # Herdr - AI agent 终端复用器
  home.packages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  # Foot 终端
  programs.foot = {
    enable = true;
    server.enable = true;
    settings = {
      main = { term = "xterm-256color"; shell = lib.getExe pkgs.brush; pad = "12x12"; };
      mouse.hide-when-typing = "yes";
      csd.preferred = "none";
      url = { launch = "\${BROWSER:-zen-beta} \${url}"; osc8-underline = "url-mode"; };
      bell = { urgent = "yes"; notify = "yes"; };
    };
  };

  # Bash 配置(brush 兼容 bash,读 .bashrc 复用此配置:aliases/initExtra/各集成 hook)
  programs.bash = {
    enable = true;
    initExtra = ''
      set -o vi
    '';
    shellAliases = {
      vi = "nvim";
      vim = "nvim";
      ll = "ls -l";
      cat = "bat";
      cls = "clear";
      # Emacs（连 daemon，-n 不阻塞终端；见 editors/emacs 的 services.emacs）
      e = "emacsclient -n -c -a emacs";   # GUI 框、不等待：e . / e file.nix
      et = "emacsclient -t -a emacs";     # 终端框（阻塞当前终端，作 TUI 用）
    };
  };

  # brush: 启用 reedline 语法高亮(nixpkgs default features 构建不含 experimental,
  # 运行时默认关闭,需 config.toml 显式开)
  xdg.configFile."brush/config.toml".text = ''
    [ui]
    syntax-highlighting = true
  '';

  # Starship prompt
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      add_newline = false;
      format = "$all";
      command_timeout = 2000;
    };
  };

  # Zoxide - 智能 cd
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [ "--cmd cd" ];
  };

  # Direnv - 自动加载环境
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  # Bat - 更好的 cat
  programs.bat.enable = true;

  # Yazi - 现代文件管理器
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    shellWrapperName = "y";
  };
}
