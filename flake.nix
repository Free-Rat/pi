{
  description = "Pi - Interactive AI coding agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      version = (builtins.fromJSON (builtins.readFile ./packages/coding-agent/package.json)).version;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nodejs = pkgs.nodejs_22;
          runtimeDeps = with pkgs; [ git fd ripgrep ]
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ xclip ];
        in
        {
          pi = pkgs.buildNpmPackage {
            pname = "pi";
            inherit version;
            src = self;
            npmDepsHash = "sha256-j5hOc2ZFAWyNNjGay1dCNhW6WVmIvTTQdYPLsrRUakE=";
            inherit nodejs;
            npmRebuildFlags = [ "--ignore-scripts" ];
            NODE_OPTIONS = "--experimental-transform-types";
            buildPhase = ''
              runHook preBuild
              npm --prefix packages/tui run build
              # Build ai: skip generate-models/generate-image-models
              # (requires network); use committed generated files instead
              ./node_modules/.bin/tsgo -p packages/ai/tsconfig.build.json
              npm --prefix packages/agent run build
              npm --prefix packages/coding-agent run build
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              npm prune --production --ignore-scripts
              mkdir -p $out/lib/pi $out/bin
              cp -a node_modules $out/lib/pi/
              cp -a packages $out/lib/pi/
              find $out/lib/pi/packages -name 'test' -type d -exec rm -rf {} + 2>/dev/null || true
              find $out/lib/pi/packages -name '*.ts' -not -name '*.d.ts' -delete 2>/dev/null || true
              find $out/lib/pi/packages -name 'tsconfig*.json' -delete 2>/dev/null || true
              makeWrapper ${nodejs}/bin/node $out/bin/pi \
                --add-flags "$out/lib/pi/packages/coding-agent/dist/cli.js" \
                --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
              runHook postInstall
            '';
            nativeBuildInputs = [ pkgs.makeWrapper ];
            meta = with pkgs.lib; {
              description = "Interactive AI coding agent";
              homepage = "https://github.com/earendil-works/pi-mono";
              license = licenses.mit;
              platforms = platforms.unix;
              mainProgram = "pi";
            };
          };
          default = self.packages.${system}.pi;
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [ nodejs_22 fd ripgrep ];
          };
        });
    };
}