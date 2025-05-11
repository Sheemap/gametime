# gametime
Board game timers!

## Development
Dependencies and environment is all built and managed with [Nix](https://nixos.org/download/) the package manager. Please make sure you have that installed.

Run `nix develop` to drop into a dev shell with all dependencies available. (Optionally) You can enable auto installing by using [direnv](https://direnv.net/) and allowing the directory.

The code is organized as a monorepo, with multiple projects as top level folders. Each individual one has its own README with any special instructions, if there are any.

## Projects

- [common](./common/README.md) - Common gleam code for all module
- [backend](./backend/README.md) - The API server for gametime
- [ui_lustre](./ui_lustre/README.md) - A lustre UI for gametime, probably will never be finished. Mainly just for me messing around and learning lustre
