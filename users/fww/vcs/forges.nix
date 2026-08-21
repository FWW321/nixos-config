# filepath: ~/nixos-config/users/fww/vcs/forges.nix
# forge 数据唯一源：HM forge.nix（ssh host 块/git insteadOf/gitconfig 用户名标记）
# 与系统级 modules/nixos/secrets.nix（gh hosts.yml 模板）共同消费
# 加新 forge = 往列表加一项，消费方自动同源不漂移
{
  forges = [
    {
      host = "github.com";
      username = "FWW321";
    }
    {
      host = "codeberg.org";
      username = "FWW";
    }
  ];
}
