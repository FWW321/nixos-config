# filepath: ~/nixos-config/modules/nixos/audio.nix
# PipeWire 音频系统
_:

{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
