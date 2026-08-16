# filepath: ~/nixos-config/users/fww/ai/dsh/settings.nix
# dsh settings.yaml 声明(freeform;启动时 yq merge,声明键覆盖、本地键保留)
{ ... }:

{
  programs.dsh = {
    # 注意:上游无 `models` 命名空间(实测 rc.5 源码),默认模型选择走
    # agent-default-model 段(见 providers.nix);此处只留通用键
    telemetry.mode = "off";
  };
}
