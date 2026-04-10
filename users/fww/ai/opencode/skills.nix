{ pkgs, lib, ... }:

let
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

  mattpocockSkillsSrc = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "main";
    sha256 = "0fq0p7npnacaps3albr3v1kwl8dvh1nmwnd9bgf1ls3i1p1di2ch";
  };

  surrealSkillsSrc = pkgs.fetchFromGitHub {
    owner = "24601";
    repo = "surreal-skills";
    rev = "main";
    sha256 = "1gdcz4i4sa7xnc5ppcx19dgha5a0n2jr0ffr5zmqqfwc4zsz0wsp";
  };

  gitWorkflowSkillSrc = pkgs.fetchFromGitHub {
    owner = "netresearch";
    repo = "git-workflow-skill";
    rev = "main";
    sha256 = "0bnwbzcfvfqc5s7cq0f5grvdwai0qynr4l9cf5qicq2fyi3vwlr8";
  };

  githubProjectSkillSrc = pkgs.fetchFromGitHub {
    owner = "netresearch";
    repo = "github-project-skill";
    rev = "main";
    sha256 = "1pgar8xqlmbvypzq4p69zw19dgvrrfyvhz3iqny2l48b529fjwf7";
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
      "opencode/skills/git-workflow" = {
        source = gitWorkflowSkillSrc;
        recursive = true;
      };
      "opencode/skills/github-project" = {
        source = githubProjectSkillSrc;
        recursive = true;
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

    {
      "opencode/skills/grill-me" = {
        source = "${mattpocockSkillsSrc}/grill-me";
        recursive = true;
      };
      "opencode/skills/design-an-interface" = {
        source = "${mattpocockSkillsSrc}/design-an-interface";
        recursive = true;
      };
      "opencode/skills/tdd" = {
        source = "${mattpocockSkillsSrc}/tdd";
        recursive = true;
      };
      "opencode/skills/improve-codebase-architecture" = {
        source = "${mattpocockSkillsSrc}/improve-codebase-architecture";
        recursive = true;
      };
    }
  ];
}
