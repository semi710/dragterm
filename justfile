@default:
    just --list

@build:
    nix build .#drag

@run file:
    nix run .#drag -- {{file}}

@dev:
    nix develop
