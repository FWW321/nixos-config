# filepath: ~/nixos-config/users/fww/ai/dsh/profiles/headless.nix
# headless profile:一次性任务面(dsh "task" → defaultProfile)
{ ... }:

{
  programs.dsh.profiles.headless.plugins = [
    "@deepseek-ai/dsh-base"
    "@deepseek-ai/dsh-headless"
  ];
}
