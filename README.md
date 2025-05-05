# gametime
Board game timers!

## Development
Dependencies and environment is all built and managed with [Nix](https://nixos.org/download/) the package manager. Please make sure you have that installed.

Run `nix develop` to drop into a dev shell with all dependencies available. (Optionally) You can enable auto installing by using [direnv](https://direnv.net/) and allowing the directory.


Once dependencies are installed, run `gleam run` to start the app! Hot reloading is enabled

## Docs
The Gametime API is defined in the `openapi.yml` file in the root of the project. You can view the docs in a prettier form with the `redoc-static.html` file.

Run the command `redocly buid-docs openapi.yml` to refresh the docs from the spec.
