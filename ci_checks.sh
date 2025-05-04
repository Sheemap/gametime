#! /usr/bin/env nix-shell
#! nix-shell -i bash -p python312Packages.openapi-spec-validator

openapi-spec-validator openapi.yml
