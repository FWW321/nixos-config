{ pkgs, lib, ... }:

let
  graphifyWrapper = pkgs.writeShellScriptBin "graphify" ''
    exec ${pkgs.uv}/bin/uvx graphifyy "$@"
  '';

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
    sha256 = "1h1zw70ka1vy4qgcarjbq1q6j3zd4fb1df0i22qhk9q8q303bcic";
  };

  golangSkillsSrc = pkgs.fetchFromGitHub {
    owner = "samber";
    repo = "cc-skills-golang";
    rev = "main";
    sha256 = "14p7jmhb10hkglgip1npf6iqmw7h48fj6v8mdndbp4b34sr6mw6p";
  };

  mattpocockSkillsSrc = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "main";
    sha256 = "0ymjhhlzfpvzsijqqc62ka34ga1m2gzbypc84w01irzxnzdsw2s3";
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
    sha256 = "00c8dqmkbf0wh1s5ybisp7wgb66i5mipwak4vn4x72qa0s2v4j5n";
  };

  githubProjectSkillSrc = pkgs.fetchFromGitHub {
    owner = "netresearch";
    repo = "github-project-skill";
    rev = "main";
    sha256 = "0znljg23m26h11ydlp0zj3w1ag2vq6yvjpayvgx5yknifqbvkpan";
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
  home.packages = [ graphifyWrapper ];

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
      "opencode/skills/github-project" = {
        source = githubProjectSkillSrc;
        recursive = true;
      };
      "opencode/skills/graphify/SKILL.md" = {
        source = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/safishamsi/graphify/master/graphify/skill-opencode.md";
          sha256 = "0091c94ahsl7jiz7abgpfba07gd5zpnv4laa6mn89jy6620frchs";
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
