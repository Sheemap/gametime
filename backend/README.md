# backend
The API for Gametime. Exposes a rest-ish API for a UI to interact with it.

## Development

```sh
gleam run   # Run the project
```

## Docs
The API is defined in the `openapi.yml` file in the root of the project. You can view the docs in a prettier form with the `redoc-static.html` file.

Run the command `redocly buid-docs openapi.yml` to refresh the docs from the spec.
