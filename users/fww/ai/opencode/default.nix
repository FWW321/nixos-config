{ config, pkgs, lib, ... }:

let
  zhipuKey = "/run/secrets/zhipu_api_key";
in
{
  imports = [
    ./mcp.nix
    ./skills.nix
    ./plugins.nix
  ];

  home.packages = [ pkgs.agent-browser pkgs.nodejs pkgs.rtk ];

  home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.brave}/bin/brave";

  home.activation.installMotionAiKit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TOKEN_PATH="/run/secrets/motion_plus_token"
    if [ ! -f "$TOKEN_PATH" ]; then
      echo "WARNING: $TOKEN_PATH not found, skipping Motion AI Kit installation"
      return 0
    fi

    TOKEN=$(cat "$TOKEN_PATH")
    SKILLS_DIR="${config.xdg.configHome}/opencode/skills"
    SCRIPT=$(${pkgs.curl}/bin/curl -sL "https://api.motion.dev/registry/skills/motion-ai-kit?token=$TOKEN")

    if [ -z "$SCRIPT" ]; then
      echo "ERROR: Failed to download Motion AI Kit script"
      return 1
    fi

    eval "$(echo "$SCRIPT" | grep -E '^SKILL_(COUNT|[0-9]+_(NAME|FILE_COUNT|FILE_[0-9]+_(PATH|B64)))=')"

    i=1
    while [ "$i" -le "$SKILL_COUNT" ]; do
      eval "skill_name=\$SKILL_''${i}_NAME"
      rm -rf "$SKILLS_DIR/$skill_name"
      i=$((i + 1))
    done

    i=1
    while [ "$i" -le "$SKILL_COUNT" ]; do
      eval "skill_name=\$SKILL_''${i}_NAME"
      eval "file_count=\$SKILL_''${i}_FILE_COUNT"
      skill_dir="$SKILLS_DIR/$skill_name"

      j=1
      while [ "$j" -le "$file_count" ]; do
        eval "rel_path=\$SKILL_''${i}_FILE_''${j}_PATH"
        eval "file_data=\$SKILL_''${i}_FILE_''${j}_B64"
        full_path="$skill_dir$rel_path"

        mkdir -p "$(dirname "$full_path")"
        printf '%s' "$file_data" | base64 -d > "$full_path"
        j=$((j + 1))
      done
      i=$((i + 1))
    done
  '';

  programs.opencode = {
    enable = true;
    settings = {
      model = "zhipuai-coding-plan/glm-5.1";
      small_model = "zhipuai-coding-plan/glm-5v-turbo";
      provider."zhipuai-coding-plan".options.apiKey = "{file:${zhipuKey}}";
    };
  };
}
