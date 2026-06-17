# filepath: ~/nixos-config/users/fww/ai/open-design.nix
# Open Design — 本地优先的开源 Claude Design 替代品
#
# 通过 Home Manager 模块运行：daemon（od CLI，:7457）+ 内置 Caddy 提供 Web SPA（:5174）。
# 数据落在 ~/.od/。daemon 自动扫描 PATH 发现 agent CLI（opencode 等）。
#
# 密钥说明：OD 不直接调 LLM，而是 spawn PATH 里的 agent CLI（你的 opencode）
# 来跑设计任务，模型 key 由 opencode 自己的配置负责 —— 默认无需在 OD 填任何 key。
# 仅当用到 OD 内置的图片/视频 provider（gpt-image-2、Seedance 等），或不想装 CLI
# 让 OD 直接走 HTTP 时，才需要在 :5174 设置界面填 key，或经 sops 注入 environmentFile。
{ config, ... }:

{
  services.open-design = {
    # 显式声明数据目录：SQLite + projects/<id>/ + artifacts/，与模块默认值一致
    dataDir = "${config.home.homeDirectory}/.od";
    enable = true;
    autoStart = true; # systemd --user 开机自启
    webFrontend.enable = true; # 起内置 Caddy，提供同源 SPA + /api 反代
    # environmentFile = config.sops.secrets.open-design-env.path;
  };
}
