{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.drag = pkgs.stdenv.mkDerivation {
        pname = "drag";
        version = "1.1.0";

        src = ./..;

        buildPhase = ''
          runHook preBuild
          clang -fobjc-arc -framework Cocoa -framework ApplicationServices \
            dragterm/main.m dragterm/DTDraggingSourceView.m \
            -o drag
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 drag $out/bin/drag
          runHook postInstall
        '';

        meta = {
          description = "Drag and drop from the command line — cursor-following fork";
          mainProgram = "drag";
          platforms = pkgs.lib.platforms.darwin;
          license = pkgs.lib.licenses.mit;
        };
      };
    };
}
