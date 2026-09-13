{
  ...
}:

{
  imports = [
    ./agents/opencode
    ./agents/zcode
    ./agents/codex.nix
    ./open-design.nix
    ./cli.nix
    ./koharu.nix
    # ComfyUI 本地栈已移除(2026-08-25):H3 生成迁 AutoDL RTX PRO 6000 96G 实例,
    # 本地 16G 卡跑 pruned 模型画质不达标(comfyui.nix 备注的"上云"路线已兑现);
    # SSH 接入与常驻隧道见 ../cloud.nix, 实例管理脚本在实例 /root/autodl-tmp/
  ];
}
