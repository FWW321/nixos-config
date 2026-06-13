{
  pkgs,
  ...
}:

let
  zhipuKey = "/run/secrets/zhipu_api_key";
in
{
  imports = [
    ./mcp.nix
    ./skills.nix
    ./plugins.nix
  ];

  home.packages = [
    pkgs.agent-browser
    pkgs.nodejs
    pkgs.rtk
  ];

  home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.brave}/bin/brave";

  programs.opencode = {
    enable = true;
    settings = {
      model = "zhipuai-coding-plan/glm-5.2";
      small_model = "zhipuai-coding-plan/glm-5.1";
      provider."zhipuai-coding-plan" = {
        options.apiKey = "{file:${zhipuKey}}";
        models = {
          "glm-5.2" = {
            name = "GLM-5.2";
            limit = {
              context = 1000000;
              output = 131072;
            };
          };
        };
      };
    };
  };
}
