{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  understandAnythingSkillDirs = [
    "understand"
    "understand-chat"
    "understand-dashboard"
    "understand-diff"
    "understand-domain"
    "understand-explain"
    "understand-knowledge"
    "understand-onboard"
  ];
in
{
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

  xdg.configFile = lib.mkMerge [
    {
      "opencode/skills/agent-browser/SKILL.md".source =
        "${inputs.agent-browser-skill}/skills/agent-browser/SKILL.md";
      "opencode/skills/humanizer-zh/SKILL.md".source =
        "${inputs.humanizer-zh}/SKILL.md";
      "opencode/skills/git-workflow" = {
        source = inputs.git-workflow-skill;
        recursive = true;
      };
    }

    {
      "opencode/skills/surrealdb" = {
        source = inputs.surreal-skills;
        recursive = true;
      };
    }

    {
      "opencode/skills/shadcn" = {
        source = "${inputs.shadcn-ui}/skills/shadcn";
        recursive = true;
      };
    }

    (lib.listToAttrs (
      map (dir: {
        name = "opencode/skills/${dir}";
        value = {
          source = "${inputs.understand-anything}/understand-anything-plugin/skills/${dir}";
          recursive = true;
        };
      }) understandAnythingSkillDirs
    ))

    {
      "opencode/skills/grill-with-docs" = {
        source = "${inputs.matt-skills}/skills/engineering/grill-with-docs";
        recursive = true;
      };
      "opencode/skills/grilling" = {
        source = "${inputs.matt-skills}/skills/productivity/grilling";
        recursive = true;
      };
      "opencode/skills/domain-modeling" = {
        source = "${inputs.matt-skills}/skills/engineering/domain-modeling";
        recursive = true;
      };
    }

    {
      "opencode/skills/herdr/SKILL.md".source = "${inputs.herdr}/SKILL.md";
    }
  ];
}
