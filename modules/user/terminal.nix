# filepath: ~/nixos-config/modules/user/terminal.nix
# 终端环境：Foot、Nushell、Herdr、现代化 CLI 工具
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
      main = { term = "xterm-256color"; shell = "nu"; pad = "12x12"; };
      mouse.hide-when-typing = "yes";
      csd.preferred = "none";
      url = { launch = "\${BROWSER:-zen-beta} \${url}"; osc8-underline = "url-mode"; };
      bell = { urgent = "yes"; notify = "yes"; };
    };
  };

  # Nushell - 现代化 shell
  programs.nushell = {
    enable = true;
    extraConfig = lib.mkMerge [
      ''
        $env.config.show_banner = false
        $env.config.edit_mode = "vi"
        $env.config.error_style = "fancy"
        $env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
      ''
      (lib.mkAfter ''
        $env.config.completions.external.completer = {|spans|
          do $carapace_completer $spans
          | where { ($in.value? | default "") !~ "ERR" }
        }
      '')
    ];
    shellAliases = {
      vi = "nvim";
      vim = "nvim";
      ll = "ls -l";
      cat = "bat";
      cls = "clear";
      # 不设 cmpa 别名：cargo-makepad 无环境变量/全局配置支持默认 sdk-path，
      # AI 用原名会下到项目目录，别名反而造成两份 SDK。顺应设计，SDK 落 ./android_33_linux_x64（.gitignore 忽略）
    };
  };

  # Carapace - 跨 shell 智能补全
  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
    enableBashIntegration = true;
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = { add_newline = false; format = "$all"; };
  };

  # Zoxide - 智能 cd
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
    options = [ "--cmd cd" ];
  };

  # Direnv - 自动加载环境
  programs.direnv = {
    enable = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  # Bat - 更好的 cat
  programs.bat.enable = true;

  # Yazi - 现代文件管理器
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    shellWrapperName = "y";
  };
}
