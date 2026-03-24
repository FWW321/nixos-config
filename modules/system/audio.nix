# filepath: ~/nixos-config/modules/system/audio.nix
# PipeWire 音频系统
{ ... }:

{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
