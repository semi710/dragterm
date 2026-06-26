{ ... }:
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      devShells.default = pkgs.mkShell {
        name = "drag-devshell";
        inputsFrom = [ config.pre-commit.devShell ];
        packages = with pkgs; [
          just
        ];
        shellHook = ''
          echo 1>&2 "🧬: $(nix eval --raw --impure --expr 'builtins.currentSystem')"
          echo 1>&2 "Ready to work on dragterm!"
        '';
      };
    };
}
