# filepath: ~/nixos-config/modules/user/terminal.nix
# 终端环境：Foot、Nushell、现代化 CLI 工具
{ ... }:

{
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
    extraConfig = ''$env.config = { show_banner: false, edit_mode: vi, error_style: "fancy" }'';
    shellAliases = { vi = "nvim"; vim = "nvim"; ll = "ls -l"; cat = "bat"; };
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
