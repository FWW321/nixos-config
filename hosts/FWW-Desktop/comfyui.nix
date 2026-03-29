{ pkgs, inputs, config, lib, ... }:

let
  dataDir = "/home/fww/comfyui-data";

  comfyui-openai-api-patched = pkgs.applyPatches {
    name = "comfyui-openai-api-envfix";
    src = pkgs.fetchFromGitHub {
      owner = "hekmon";
      repo = "comfyui-openai-api";
      rev = "efb68c42291ae77df665423e02d6885a3f556bd1";
      hash = "sha256-nVobD5HH8DmpCyUDuPWgYSkNKkHJ6Uk1etFpM74FgEM=";
    };
    postPatch = ''
      sed -i 's/api_key=api_key,/api_key=None if api_key in ("-", "") else api_key,/' client.py
    '';
  };

  workflow-t2i = pkgs.writeText "flux2-klein-t2i.json" (builtins.toJSON {
    id = "flux2-klein-t2i";
    revision = 0;
    last_nodeId = 15;
    last_linkId = 17;
    nodes = [
      {
        id = 1;
        type = "UNETLoader";
        pos = [ 100 0 ];
        size = [ 270 82 ];
        flags = {};
        order = 0;
        mode = 0;
        inputs = [];
        outputs = [{ name = "MODEL"; type = "MODEL"; slot_index = 0; links = [ 1 ]; }];
        properties = { "Node name for S&R" = "UNETLoader"; };
        widgets_values = [ "flux-2-klein-9b-fp8.safetensors" "default" ];
      }
      {
        id = 2;
        type = "CLIPLoader";
        pos = [ 100 120 ];
        size = [ 270 106 ];
        flags = {};
        order = 1;
        mode = 0;
        inputs = [];
        outputs = [{ name = "CLIP"; type = "CLIP"; slot_index = 0; links = [ 2 ]; }];
        properties = { "Node name for S&R" = "CLIPLoader"; };
        widgets_values = [ "qwen_3_8b_fp8mixed.safetensors" "flux2" "default" ];
      }
      {
        id = 3;
        type = "VAELoader";
        pos = [ 100 260 ];
        size = [ 270 60 ];
        flags = {};
        order = 2;
        mode = 0;
        inputs = [];
        outputs = [{ name = "VAE"; type = "VAE"; slot_index = 0; links = [ 6 ]; }];
        properties = { "Node name for S&R" = "VAELoader"; };
        widgets_values = [ "flux2-vae.safetensors" ];
      }
      {
        id = 4;
        type = "EmptyFlux2LatentImage";
        pos = [ 100 360 ];
        size = [ 270 106 ];
        flags = {};
        order = 3;
        mode = 0;
        inputs = [];
        outputs = [{ name = "LATENT"; type = "LATENT"; slot_index = 0; links = [ 7 ]; }];
        properties = { "Node name for S&R" = "EmptyFlux2LatentImage"; };
        widgets_values = [ 1024 1024 1 ];
      }
      {
        id = 12;
        type = "LoraLoader";
        pos = [ 420 0 ];
        size = [ 270 100 ];
        flags = {};
        order = 4;
        mode = 0;
        inputs = [
          { name = "model"; type = "MODEL"; link = 1; }
          { name = "clip"; type = "CLIP"; link = 2; }
        ];
        outputs = [
          { name = "MODEL"; type = "MODEL"; slot_index = 0; links = [ 12 ]; }
          { name = "CLIP"; type = "CLIP"; slot_index = 1; links = [ 13 ]; }
        ];
        title = "LoRA: NippleDiffusion";
        properties = { "Node name for S&R" = "LoraLoader"; };
        widgets_values = [ "nipplediffusion-f2-klein-9b_v3.safetensors" 0.8 0.8 ];
      }
      {
        id = 13;
        type = "LoraLoader";
        pos = [ 740 0 ];
        size = [ 270 100 ];
        flags = {};
        order = 5;
        mode = 0;
        inputs = [
          { name = "model"; type = "MODEL"; link = 12; }
          { name = "clip"; type = "CLIP"; link = 13; }
        ];
        outputs = [
          { name = "MODEL"; type = "MODEL"; slot_index = 0; links = [ 14 ]; }
          { name = "CLIP"; type = "CLIP"; slot_index = 1; links = [ 15 ]; }
        ];
        title = "LoRA: Anatomy Fix";
        properties = { "Node name for S&R" = "LoraLoader"; };
        widgets_values = [ "klein_slider_anatomy.safetensors" 0.8 0.8 ];
      }
      {
        id = 5;
        type = "OAIAPI_Client";
        pos = [ 100 520 ];
        size = [ 320 140 ];
        flags = {};
        order = 6;
        mode = 0;
        inputs = [];
        outputs = [{ name = "API Client"; type = "OAIAPI_CLIENT"; slot_index = 0; links = [ 3 ]; }];
        title = "GLM API Client";
        properties = { "Node name for S&R" = "OAIAPI_Client"; };
        widgets_values = [ "https://open.bigmodel.cn/api/coding/paas/v4" 2 600 "-" ];
      }
      {
        id = 6;
        type = "OAIAPI_ChatCompletion";
        pos = [ 480 520 ];
        size = [ 400 260 ];
        flags = {};
        order = 7;
        mode = 0;
        inputs = [{ name = "client"; type = "OAIAPI_CLIENT"; link = 3; }];
        outputs = [
          { name = "Response"; type = "STRING"; slot_index = 0; links = [ 4 ]; }
          { name = "History"; type = "OAIAPI_HISTORY"; slot_index = 1; links = []; }
        ];
        title = "GLM Prompt Enhancement";
        properties = { "Node name for S&R" = "OAIAPI_ChatCompletion"; };
        widgets_values = [
          "glm-5.1"
          false
          "a beautiful woman standing in a garden, sunlight, flowers"
          "You are an expert prompt engineer for FLUX.2 Klein image generation. Given a brief description, expand it into a detailed prompt following these rules:\n1. Write in flowing natural language like a novelist, NOT keyword lists\n2. LIGHTING is the single most important element - describe source, quality, direction, temperature\n3. Word order matters - front-load the most important elements\n4. Structure: Subject \u2192 Setting \u2192 Details \u2192 Lighting \u2192 Atmosphere\n5. Be specific with colors, textures, materials\n6. For style, reference camera/film type or artistic medium\n\nOutput ONLY the enhanced prompt in English. Keep it between 50-150 words."
        ];
        color = "#223";
        bgcolor = "#335";
      }
      {
        id = 7;
        type = "CLIPTextEncode";
        pos = [ 940 0 ];
        size = [ 400 200 ];
        flags = {};
        order = 8;
        mode = 0;
        inputs = [
          { name = "clip"; type = "CLIP"; link = 15; }
          { name = "text"; type = "STRING"; link = 4; widget = { name = "text"; }; }
        ];
        outputs = [{ name = "CONDITIONING"; type = "CONDITIONING"; slot_index = 0; links = [ 5 8 ]; }];
        title = "Positive Prompt (from GLM)";
        properties = { "Node name for S&R" = "CLIPTextEncode"; };
        widgets_values = [ "" ];
      }
      {
        id = 14;
        type = "Flux2KleinEnhancer";
        pos = [ 1200 0 ];
        size = [ 280 160 ];
        flags = {};
        order = 9;
        mode = 0;
        inputs = [{ name = "conditioning"; type = "CONDITIONING"; link = 5; }];
        outputs = [{ name = "CONDITIONING"; type = "CONDITIONING"; slot_index = 0; links = [ 16 ]; }];
        title = "Klein Enhancer (Strong)";
        properties = { "Node name for S&R" = "Flux2KleinEnhancer"; };
        widgets_values = [ 1.35 0.30 0.15 0.0 "linear" 1.0 0 false "auto" false ];
        color = "#223";
        bgcolor = "#335";
      }
      {
        id = 15;
        type = "FluxGuidance";
        pos = [ 1400 0 ];
        size = [ 220 60 ];
        flags = {};
        order = 10;
        mode = 0;
        inputs = [{ name = "conditioning"; type = "CONDITIONING"; link = 16; }];
        outputs = [{ name = "CONDITIONING"; type = "CONDITIONING"; slot_index = 0; links = [ 17 ]; }];
        properties = { "Node name for S&R" = "FluxGuidance"; };
        widgets_values = [ 4 ];
        color = "#233";
        bgcolor = "#355";
      }
      {
        id = 8;
        type = "ConditioningZeroOut";
        pos = [ 940 260 ];
        size = [ 210 30 ];
        flags = {};
        order = 11;
        mode = 0;
        inputs = [{ name = "conditioning"; type = "CONDITIONING"; link = 8; }];
        outputs = [{ name = "CONDITIONING"; type = "CONDITIONING"; slot_index = 0; links = [ 9 ]; }];
        properties = { "Node name for S&R" = "ConditioningZeroOut"; };
        widgets_values = [];
      }
      {
        id = 9;
        type = "KSampler";
        pos = [ 1550 0 ];
        size = [ 300 260 ];
        flags = {};
        order = 12;
        mode = 0;
        inputs = [
          { name = "model"; type = "MODEL"; link = 14; }
          { name = "positive"; type = "CONDITIONING"; link = 17; }
          { name = "negative"; type = "CONDITIONING"; link = 9; }
          { name = "latent_image"; type = "LATENT"; link = 7; }
        ];
        outputs = [{ name = "LATENT"; type = "LATENT"; slot_index = 0; links = [ 10 ]; }];
        properties = { "Node name for S&R" = "KSampler"; };
        widgets_values = [ 0 "randomize" 8 1.0 "euler" "simple" 1.0 ];
      }
      {
        id = 10;
        type = "VAEDecode";
        pos = [ 1750 0 ];
        size = [ 210 46 ];
        flags = {};
        order = 13;
        mode = 0;
        inputs = [
          { name = "samples"; type = "LATENT"; link = 10; }
          { name = "vae"; type = "VAE"; link = 6; }
        ];
        outputs = [{ name = "IMAGE"; type = "IMAGE"; slot_index = 0; links = [ 11 ]; }];
        properties = { "Node name for S&R" = "VAEDecode"; };
        widgets_values = [];
      }
      {
        id = 11;
        type = "SaveImage";
        pos = [ 2000 0 ];
        size = [ 500 500 ];
        flags = {};
        order = 14;
        mode = 0;
        inputs = [{ name = "images"; type = "IMAGE"; link = 11; }];
        outputs = [];
        properties = { "Node name for S&R" = "SaveImage"; };
        widgets_values = [ "FLUX2_Klein9B" ];
      }
    ];
    links = [
      [ 1   1 0 12 0 "MODEL" ]
      [ 2   2 0 12 1 "CLIP" ]
      [ 3   5 0  6 0 "OAIAPI_CLIENT" ]
      [ 4   6 0  7 1 "STRING" ]
      [ 5   7 0 14 0 "CONDITIONING" ]
      [ 6   3 0 10 1 "VAE" ]
      [ 7   4 0  9 3 "LATENT" ]
      [ 8   7 0  8 0 "CONDITIONING" ]
      [ 9   8 0  9 2 "CONDITIONING" ]
      [ 10  9 0 10 0 "LATENT" ]
      [ 11 10 0 11 0 "IMAGE" ]
      [ 12 12 0 13 0 "MODEL" ]
      [ 13 12 1 13 1 "CLIP" ]
      [ 14 13 0  9 0 "MODEL" ]
      [ 15 13 1  7 0 "CLIP" ]
      [ 16 14 0 15 0 "CONDITIONING" ]
      [ 17 15 0  9 1 "CONDITIONING" ]
    ];
    groups = [];
    config = {};
    extra = {
      info = {
        name = "FLUX.2 Klein 9B T2I";
        description = "GLM-5.1 prompt + Klein Enhancer + LoRA, euler/simple 8 steps";
      };
    };
    version = 0.4;
  });

in

{
  nixpkgs.overlays = [ inputs.comfyui-nix.overlays.default ];

  services.comfyui = {
    enable = true;
    gpuSupport = "cuda";
    cudaCapabilities = [ "8.9" ];
    enableManager = true;
    port = 8188;
    listenAddress = "127.0.0.1";
    dataDir = dataDir;
    user = "fww";
    group = "users";
    createUser = false;
    extraArgs = [ "--cache-none" ];
    customNodes = {
      comfyui-openai-api = comfyui-openai-api-patched;
      ComfyUI-Flux2Klein-Enhancer = pkgs.fetchFromGitHub {
        owner = "capitan01R";
        repo = "ComfyUI-Flux2Klein-Enhancer";
        rev = "d65dcf8fbe6165777440ff442ec30573740659f1";
        hash = "sha256-0eAoQ46bPnUmdj4bhOSA29mpcHf4HCz4359mD9kN7XI=";
      };
    };
  };

  systemd.services.comfyui.preStart = ''
    VENV="${dataDir}/.venv"
    UV="${pkgs.uv}/bin/uv"
    PY="$VENV/bin/python"

    $UV pip show --python "$PY" openai >/dev/null 2>&1 || $UV pip install --python "$PY" openai

    SETTINGS="${dataDir}/user/default/comfy.settings.json"
    if [ -f "$SETTINGS" ]; then
      "${pkgs.python312}/bin/python" -c "
import json
with open('$SETTINGS') as f:
    s = json.load(f)
s['Comfy.VueNodes.Enabled'] = True
with open('$SETTINGS', 'w') as f:
    json.dump(s, f, indent=4)
"
    fi
  '';

  systemd.services.comfyui.serviceConfig.EnvironmentFile =
    config.sops.templates."comfyui-env".path;

  sops.templates."comfyui-env" = {
    owner = "fww";
    content = ''
      HF_TOKEN=${config.sops.placeholder.hf_token}
      CIVITAI_TOKEN=${config.sops.placeholder.civitai_token}
      ZHIPU_API_KEY=${config.sops.placeholder.zhipu_api_key}
      OPENAI_API_KEY=${config.sops.placeholder.zhipu_api_key}
    '';
  };

  systemd.tmpfiles.rules = [
    "L+ ${dataDir}/user/default/workflows/flux2-klein-t2i.json - - - - ${workflow-t2i}"
  ];

  systemd.services.comfyui-download-models = {
    description = "Download ComfyUI FLUX.2 Klein 9B models and LoRA";
    after = [ "network-online.target" "sops-nix.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    before = [ "comfyui.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "fww";
      Group = "users";
      RemainAfterExit = true;
      EnvironmentFile = config.sops.templates."comfyui-env".path;
    };
    path = with pkgs; [ curl ];
    script = ''
      MODELS="${dataDir}/models"
      HF="https://huggingface.co"

      download() {
        local dest="$1" url="$2" token="''${3:-}"
        local out="$MODELS/$dest"
        if [ -f "$out" ]; then
          echo "exists: $dest"
          return
        fi
        echo "downloading: $dest"
        mkdir -p "$(dirname "$out")"
        if [ -n "$token" ]; then
          curl -L --progress-bar -o "$out" -H "Authorization: Bearer $token" "$url"
        else
          curl -L --progress-bar -o "$out" "$url"
        fi
        if [ $? -ne 0 ]; then
          echo "failed: $dest"
          rm -f "$out"
        fi
      }

      download "diffusion_models/flux-2-klein-9b-fp8.safetensors" \
        "$HF/black-forest-labs/FLUX.2-klein-9b-fp8/resolve/main/flux-2-klein-9b-fp8.safetensors" \
        "$HF_TOKEN"

      download "text_encoders/qwen_3_8b_fp8mixed.safetensors" \
        "$HF/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
        "$HF_TOKEN"

      download "vae/flux2-vae.safetensors" \
        "$HF/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/vae/flux2-vae.safetensors" \
        "$HF_TOKEN"

      download "loras/nipplediffusion-f2-klein-9b_v3.safetensors" \
        "https://civitai.com/api/download/models/2749020?token=$CIVITAI_TOKEN" \
        ""

      download "loras/klein_slider_anatomy.safetensors" \
        "https://civitai.com/api/download/models/2615554?token=$CIVITAI_TOKEN" \
        ""
    '';
  };
}
