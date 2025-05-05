{ ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";

  # Enable the various formatters
  programs.nixfmt.enable = true;
  programs.gleam.enable = true;
}
