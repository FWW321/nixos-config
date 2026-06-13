{
  config,
  pkgs,
  lib,
  ...
}:

let
  rustSkillsSrc = pkgs.fetchFromGitHub {
    owner = "actionbook";
    repo = "rust-skills";
    rev = "main";
    sha256 = "157rssync4939v1kwkkrkwcj7qlcak7vadmaimwf7nlwg1xggblj";
  };

  shadcnSkillSrc = pkgs.fetchFromGitHub {
    owner = "shadcn-ui";
    repo = "ui";
    rev = "main";
    sha256 = "0kvly0plh4qq736yvrkkminxkn2ixr3jwz80mr6w1kdrxyvf5pg8";
  };

  golangSkillsSrc = pkgs.fetchFromGitHub {
    owner = "samber";
    repo = "cc-skills-golang";
    rev = "main";
    sha256 = "02gxl5hznxh99a6n9lbzahzlpl4zd16axgldsfvks00c06i7lkb7";
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

  uiuxProMaxSrc = pkgs.fetchFromGitHub {
    owner = "nextlevelbuilder";
    repo = "ui-ux-pro-max-skill";
    rev = "main";
    sha256 = "0fjfr15ky6yj9w26fc0mk7jsv46lqb89987s1h47yk48vrkaf0dn";
  };

  uiuxProMaxSkillMd =
    let
      template = builtins.readFile "${uiuxProMaxSrc}/src/ui-ux-pro-max/templates/base/skill-content.md";
      frontmatter = ''
        ---
        name: ui-ux-pro-max
        description: "UI/UX design intelligence with searchable database"
        ---

      '';
      content =
        builtins.replaceStrings
          [ "{{TITLE}}" "{{DESCRIPTION}}" "{{SCRIPT_PATH}}" "{{SKILL_OR_WORKFLOW}}" "{{QUICK_REFERENCE}}" ]
          [
            "ui-ux-pro-max"
            "Comprehensive design guide for web and mobile applications. Contains 67 styles, 161 color palettes, 57 font pairings, 99 UX guidelines, and 25 chart types across 16 technology stacks. Searchable database with priority-based recommendations."
            "scripts/search.py"
            "Skill"
            ""
          ]
          template;
    in
    pkgs.writeText "ui-ux-pro-max-SKILL.md" (frontmatter + content);

  rustSkillDirs = [
    "rust-router"
    "core-actionbook"
    "core-agent-browser"
    "core-dynamic-skills"
    "core-fix-skill-docs"
    "coding-guidelines"
    "m01-ownership"
    "m02-resource"
    "m03-mutability"
    "m04-zero-cost"
    "m05-type-driven"
    "m06-error-handling"
    "m07-concurrency"
    "m09-domain"
    "m10-performance"
    "m11-ecosystem"
    "m12-lifecycle"
    "m13-domain-error"
    "m14-mental-model"
    "m15-anti-pattern"
    "meta-cognition-parallel"
    "domain-cli"
    "domain-cloud-native"
    "domain-embedded"
    "domain-fintech"
    "domain-iot"
    "domain-ml"
    "domain-web"
    "rust-call-graph"
    "rust-code-navigator"
    "rust-daily"
    "rust-deps-visualizer"
    "rust-learner"
    "rust-refactor-helper"
    "rust-skill-creator"
    "rust-symbol-analyzer"
    "rust-trait-explorer"
    "unsafe-checker"
  ];

  golangSkillDirs = [
    "golang-benchmark"
    "golang-cli"
    "golang-code-style"
    "golang-concurrency"
    "golang-context"
    "golang-continuous-integration"
    "golang-data-structures"
    "golang-database"
    "golang-dependency-injection"
    "golang-dependency-management"
    "golang-design-patterns"
    "golang-documentation"
    "golang-error-handling"
    "golang-grpc"
    "golang-linter"
    "golang-modernize"
    "golang-naming"
    "golang-observability"
    "golang-performance"
    "golang-popular-libraries"
    "golang-project-layout"
    "golang-safety"
    "golang-samber-do"
    "golang-samber-hot"
    "golang-samber-lo"
    "golang-samber-mo"
    "golang-samber-oops"
    "golang-samber-ro"
    "golang-samber-slog"
    "golang-security"
    "golang-stay-updated"
    "golang-stretchr-testify"
    "golang-structs-interfaces"
    "golang-testing"
    "golang-troubleshooting"
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

    (lib.listToAttrs (
      map (dir: {
        name = "opencode/skills/${dir}";
        value = {
          source = "${rustSkillsSrc}/skills/${dir}";
          recursive = true;
        };
      }) rustSkillDirs
    ))

    (lib.listToAttrs (
      map (dir: {
        name = "opencode/skills/${dir}";
        value = {
          source = "${golangSkillsSrc}/skills/${dir}";
          recursive = true;
        };
      }) golangSkillDirs
    ))

    {
      "opencode/skills/ui-ux-pro-max/SKILL.md".source = uiuxProMaxSkillMd;
      "opencode/skills/ui-ux-pro-max/data" = {
        source = "${uiuxProMaxSrc}/src/ui-ux-pro-max/data";
        recursive = true;
      };
      "opencode/skills/ui-ux-pro-max/scripts" = {
        source = "${uiuxProMaxSrc}/src/ui-ux-pro-max/scripts";
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
  ];
}
