{ config, pkgs, lib, ... }:

let
  zhipuKey = "/run/secrets/zhipu_api_key";
  context7Key = "/run/secrets/context7_key";

  rustSkillsSrc = pkgs.fetchFromGitHub {
    owner = "actionbook";
    repo = "rust-skills";
    rev = "main";
    sha256 = "0056bbl00g9ainrkjkg78c17ahv4cihwi05in350pb575a6d8dnk";
  };

  shadcnSkillSrc = pkgs.fetchFromGitHub {
    owner = "shadcn-ui";
    repo = "ui";
    rev = "main";
    sha256 = "1ha7mlihd286f6d7mzpz5v78p4ghrvbyyxv0d7q6x6i4ha24aznn";
  };

  golangSkillsSrc = pkgs.fetchFromGitHub {
    owner = "samber";
    repo = "cc-skills-golang";
    rev = "main";
    sha256 = "0w665npjky1y824csk9lajdvanmz61va0zxwf9m2jxaqdg3awdpm";
  };

  uiuxProMaxSrc = pkgs.fetchFromGitHub {
    owner = "nextlevelbuilder";
    repo = "ui-ux-pro-max-skill";
    rev = "main";
    sha256 = "0fjfr15ky6yj9w26fc0mk7jsv46lqb89987s1h47yk48vrkaf0dn";
  };

  uiuxProMaxSkillMd = let
    template = builtins.readFile "${uiuxProMaxSrc}/src/ui-ux-pro-max/templates/base/skill-content.md";
    frontmatter = ''
      ---
      name: ui-ux-pro-max
      description: "UI/UX design intelligence with searchable database"
      ---

    '';
    content = builtins.replaceStrings
      [ "{{TITLE}}" "{{DESCRIPTION}}" "{{SCRIPT_PATH}}" "{{SKILL_OR_WORKFLOW}}" "{{QUICK_REFERENCE}}" ]
      [
        "ui-ux-pro-max"
        "Comprehensive design guide for web and mobile applications. Contains 67 styles, 161 color palettes, 57 font pairings, 99 UX guidelines, and 25 chart types across 16 technology stacks. Searchable database with priority-based recommendations."
        "scripts/search.py"
        "Skill"
        ""
      ]
      template;
  in pkgs.writeText "ui-ux-pro-max-SKILL.md" (frontmatter + content);

  rustSkillDirs = [
    "rust-router" "core-actionbook" "core-agent-browser" "core-dynamic-skills"
    "core-fix-skill-docs" "coding-guidelines"
    "m01-ownership" "m02-resource" "m03-mutability" "m04-zero-cost"
    "m05-type-driven" "m06-error-handling" "m07-concurrency"
    "m09-domain" "m10-performance" "m11-ecosystem" "m12-lifecycle"
    "m13-domain-error" "m14-mental-model" "m15-anti-pattern"
    "meta-cognition-parallel"
    "domain-cli" "domain-cloud-native" "domain-embedded" "domain-fintech"
    "domain-iot" "domain-ml" "domain-web"
    "rust-call-graph" "rust-code-navigator" "rust-daily" "rust-deps-visualizer"
    "rust-learner" "rust-refactor-helper" "rust-skill-creator"
    "rust-symbol-analyzer" "rust-trait-explorer" "unsafe-checker"
  ];

  golangSkillDirs = [
    "golang-benchmark" "golang-cli" "golang-code-style" "golang-concurrency"
    "golang-context" "golang-continuous-integration" "golang-data-structures"
    "golang-database" "golang-dependency-injection" "golang-dependency-management"
    "golang-design-patterns" "golang-documentation" "golang-error-handling"
    "golang-grpc" "golang-linter" "golang-modernize" "golang-naming"
    "golang-observability" "golang-performance" "golang-popular-libraries"
    "golang-project-layout" "golang-safety" "golang-samber-do" "golang-samber-hot"
    "golang-samber-lo" "golang-samber-mo" "golang-samber-oops" "golang-samber-ro"
    "golang-samber-slog" "golang-security" "golang-stay-updated"
    "golang-stretchr-testify" "golang-structs-interfaces" "golang-testing"
    "golang-troubleshooting"
  ];

in
{
  home.packages = [ pkgs.agent-browser pkgs.nodejs ];

  home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.brave}/bin/brave";

  xdg.configFile = lib.mkMerge [
    {
      "opencode/skills/agent-browser/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md";
          sha256 = "0m8ai678bl28whp2n3763gzcvr5xyn4kc2fdgkkasq0n3q4wnhdk";
        };
      };
      "opencode/skills/humanizer-zh/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/op7418/Humanizer-zh/main/SKILL.md";
          sha256 = "1sxywjd9xmxz298c76gxi3hr8my9xadvagspsmil4r08j2ybvvg0";
        };
      };
      "opencode/skills/conventional-git/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/samber/cc-skills/main/skills/conventional-git/SKILL.md";
          sha256 = "1zsnmr6xwpjgxqmc0c88x7h42nhjnc7mskrcf8ziwyh0ywzs6vl1";
        };
      };
      "opencode/skills/security-audit/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/openclaw/skills/main/skills/kingrubic/agentic-security-audit/SKILL.md";
          sha256 = "1zg82f8al1xkzkw5wf37lhb5243ndqa7xcrp1jxxbgk23zavychf";
        };
      };
      "opencode/skills/cicd-pipeline/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/openclaw/skills/main/skills/gitgoodordietrying/cicd-pipeline/SKILL.md";
          sha256 = "1ayx3g74nshrnasyy3k1d970k3ni2n1v18hd4yv68z9a7n9rx3xp";
        };
      };
    }

    (lib.listToAttrs (map (dir: {
      name = "opencode/skills/${dir}";
      value = { source = "${rustSkillsSrc}/skills/${dir}"; recursive = true; };
    }) rustSkillDirs))

    (lib.listToAttrs (map (dir: {
      name = "opencode/skills/${dir}";
      value = { source = "${golangSkillsSrc}/skills/${dir}"; recursive = true; };
    }) golangSkillDirs))

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
      "opencode/skills/shadcn" = {
        source = "${shadcnSkillSrc}/skills/shadcn";
        recursive = true;
      };
    }
  ];

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
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
          headers.CONTEXT7_API_KEY = "{file:${context7Key}}";
          enabled = true;
        };
        "zai-mcp-server" = {
          type = "local";
          enabled = true;
          command = [ "bunx" "-y" "@z_ai/mcp-server" ];
          environment = {
            Z_AI_API_KEY = "{file:${zhipuKey}}";
            Z_AI_MODE = "ZHIPU";
          };
        };
        "web-search-prime" = {
          type = "remote";
          enabled = true;
          url = "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp";
          headers.Authorization = "Bearer {file:${zhipuKey}}";
        };
        "web-reader" = {
          type = "remote";
          enabled = true;
          url = "https://open.bigmodel.cn/api/mcp/web_reader/mcp";
          headers.Authorization = "Bearer {file:${zhipuKey}}";
        };
        "zread" = {
          type = "remote";
          enabled = true;
          url = "https://open.bigmodel.cn/api/mcp/zread/mcp";
          headers.Authorization = "Bearer {file:${zhipuKey}}";
        };
        "motion-studio" = {
          type = "local";
          enabled = true;
          command = [ "npx" "-y" "https://api.motion.dev/registry.tgz?package=motion-studio-mcp&version=latest" ];
          environment.TOKEN = "{file:/run/secrets/motion_plus_token}";
        };
        "mcp-server-tauri" = {
          type = "local";
          enabled = true;
          command = [ "npx" "-y" "@hypothesi/tauri-mcp-server" ];
        };
        "shadcn" = {
          type = "local";
          enabled = true;
          command = [ "npx" "-y" "shadcn@latest" "mcp" ];
        };
      };
    };
  };
}
