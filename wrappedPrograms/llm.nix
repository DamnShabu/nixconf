{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
  in {
    packages.ask = pkgs.writeShellApplication {
      name = "ask";
      runtimeInputs = [pkgs.jq];
      text = ''
        # ponytail: secrets are purged from tmpfs after idle; re-decrypt on
        # demand by restarting sops-install-secrets (allowed via polkit for wheel)
        if [ ! -s /run/secrets/connection.json ]; then
          systemctl restart sops-install-secrets.service 2>/dev/null || true
        fi
        API_KEY=$(jq -r '.openrouter // empty' /run/secrets/connection.json)
        PROMPT="''${1:-$(cat)}"

        DATA=$(jq -n --arg model "google/gemini-3.1-flash-lite" --arg content "$PROMPT" '{
          model: $model,
          messages: [{role: "user", content: $content}]
        }')

        curl -s https://openrouter.ai/api/v1/chat/completions \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -H "HTTP-Referer: https://local" \
          -H "X-Title: cli" \
          -d "$DATA" \
        | ${lib.getExe pkgs.jq} -r '.choices[0].message.content'
      '';
    };
  };
}
