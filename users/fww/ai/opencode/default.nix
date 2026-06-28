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
    pkgs.rtk
  ];

  home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "brave";

  programs.opencode = {
    enable = true;
    settings = {
      model = "zhipuai-coding-plan/glm-5.2";
      small_model = "zhipuai-coding-plan/glm-5.1";
      # 启用 LSP：opencode 自动下载所需的 language server 到自己的数据目录，
      # 并将诊断信息作为反馈喂给 agent
      lsp = true;
      provider."zhipuai-coding-plan" = {
        options.apiKey = "{file:${zhipuKey}}";
      };
    };
  };
}
