{ pkgs, inputs, ... }:

{
  rtk = {
    package = pkgs.rtk;
    source = inputs.rtk;
  };
  herdr = {
    source = inputs.herdr;
  };
}
