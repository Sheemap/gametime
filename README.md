# gametime
Board game timers!

## Development
Dependencies and environment is all built and managed with [Nix](https://nixos.org/download/) the package manager. Please make sure you have that installed.

Run `nix develop` to drop into a dev shell with all dependencies available.

You can have it do this automatically by installing [direnv](https://direnv.net/) and allowing the directory.

## API Client
The docs are currently in a format for [Bruno](https://www.usebruno.com/). Ideally would like an OpenAPI spec, and will likely move to that.

In the meantime, you can run Bruno from your CLI by running `nix run .#bruno` (Or install it seperately)
