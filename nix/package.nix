{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      packages.default = config.packages.drag;

      packages.drag = pkgs.stdenv.mkDerivation rec {
        pname = "drag";
        version = "1.1.2";

        src = ./..;

        buildPhase = ''
          runHook preBuild
          # Bare binaries carry no bundle; embed a real Info.plist so --version works.
          # Keep the copyright in sync with dragterm/Info.plist.
          cat > embedded-info.plist <<PLIST
          <?xml version="1.0" encoding="UTF-8"?>
          <plist version="1.0">
          <dict>
          <key>CFBundleShortVersionString</key>
          <string>${version}</string>
          <key>CFBundleVersion</key>
          <string>${version}</string>
          <key>NSHumanReadableCopyright</key>
          <string>© 2019–2025 Nate Weaver (Wevah)/Derailer</string>
          </dict>
          </plist>
          PLIST
          clang -fobjc-arc -framework Cocoa -framework ApplicationServices -framework QuickLookThumbnailing \
            -Wl,-sectcreate,__TEXT,__info_plist,embedded-info.plist \
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
