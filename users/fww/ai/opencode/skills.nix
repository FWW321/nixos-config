{
  config,
  pkgs,
  lib,
  ...
}:

let
  shadcnSkillSrc = pkgs.fetchFromGitHub {
    owner = "shadcn-ui";
    repo = "ui";
    rev = "main";
    sha256 = "0kvly0plh4qq736yvrkkminxkn2ixr3jwz80mr6w1kdrxyvf5pg8";
  };

  surrealSkillsSrc = pkgs.fetchFromGitHub {
    owner = "24601";
    repo = "surreal-skills";
    rev = "main";
    sha256 = "18fcdyyl6dbksba5pbn277ajaawr2bgmy9z9rb27n57fp8mh7sb8";
  };

  gitWorkflowSkillSrc = pkgs.fetchFromGitHub {
    owner = "netresearch";
    repo = "git-workflow-skill";
    rev = "main";
    sha256 = "1137nd1krgxhgzhvnw32nqjz327ifsp791s9clmmdcbldqs805yh";
  };

  understandAnythingSrc = pkgs.fetchFromGitHub {
    owner = "Egonex-AI";
    repo = "Understand-Anything";
    rev = "main";
    sha256 = "08gdri49xw4a98vqcmck7bkcy5abzhfv06hjzirgq3ch7vhl6gv8";
  };

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

  mattSkillsSrc = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "6eeb81b5fcfeeb5bd531dd47ab2f9f2bbea27461";
    sha256 = "sha256-6T0KwZcUIIbd6kpkQXPCnnJPVY2mEjxYjed4FjKnRAw=";
  };

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
      "opencode/skills/agent-browser/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md";
          sha256 = "0b74mbx6km6b4k6kyagmrvbfd7a6w0dqnxq98rivn33x0rhrhw00";
        };
      };
      "opencode/skills/humanizer-zh/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/op7418/Humanizer-zh/main/SKILL.md";
          sha256 = "1sxywjd9xmxz298c76gxi3hr8my9xadvagspsmil4r08j2ybvvg0";
        };
      };
      "opencode/skills/git-workflow" = {
        source = gitWorkflowSkillSrc;
        recursive = true;
      };
    }

    {
      "opencode/skills/surrealdb" = {
        source = surrealSkillsSrc;
        recursive = true;
      };
    }

    {
      "opencode/skills/shadcn" = {
        source = "${shadcnSkillSrc}/skills/shadcn";
        recursive = true;
      };
    }

    (lib.listToAttrs (
      map (dir: {
        name = "opencode/skills/${dir}";
        value = {
          source = "${understandAnythingSrc}/understand-anything-plugin/skills/${dir}";
          recursive = true;
        };
      }) understandAnythingSkillDirs
    ))

    {
      "opencode/skills/grill-with-docs" = {
        source = "${mattSkillsSrc}/skills/engineering/grill-with-docs";
        recursive = true;
      };
      "opencode/skills/grilling" = {
        source = "${mattSkillsSrc}/skills/productivity/grilling";
        recursive = true;
      };
      "opencode/skills/domain-modeling" = {
        source = "${mattSkillsSrc}/skills/engineering/domain-modeling";
        recursive = true;
      };
    }
  ];
}
