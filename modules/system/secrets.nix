{ ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      user_password.neededForUsers = true;
      github_token.owner = "fww";
      zhipu_api_key.owner = "fww";
      context7_key.owner = "fww";
      hf_token.owner = "fww";
      civitai_token.owner = "fww";
    };
  };
}
