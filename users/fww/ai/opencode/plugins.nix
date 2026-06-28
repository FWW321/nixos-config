{ inputs, ... }:

{
  programs.opencode.settings.plugin = [
    "opencode-pty"
    "opencode-handoff"
  ];

  xdg.configFile."opencode/plugins/rtk.ts".source =
    "${inputs.rtk}/hooks/opencode/rtk.ts";
  xdg.configFile."opencode/plugins/herdr-agent-state.js".source =
    "${inputs.herdr}/src/integration/assets/opencode/herdr-agent-state.js";
}
