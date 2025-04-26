import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string_tree
import web/json_decoders
import web/middleware
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- middleware.initial(req)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    // [] -> home_page(req)
    // This matches `/todos`.
    // ["todos"] -> todos(req)
    // This matches `/todos/:id`.
    // The `id` segment is bound to a variable and passed to the handler.
    // ["todos", id] -> handle_todo(req, id)
    // Create a lobby
    ["api", "v1", "create-lobby"] -> create_lobby(req)
    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn create_unprocessable_error(errors: List(decode.DecodeError)) {
  errors
  |> list.map(fn(err) {
    json.object([
      #("expected", json.string(err.expected)),
      #("found", json.string(err.found)),
      #("path", json.array(err.path, json.string)),
    ])
  })
  |> json.preprocessed_array
}

/// Create's a lobby
fn create_lobby(req) {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_json(req)

  case decode.run(body, json_decoders.create_lobby_decoder()) {
    Ok(model) ->
      wisp.ok()
      |> wisp.json_body(string_tree.from_string("{\"lobbyId\": \"ID yay!\"}"))
    Error(errors) -> {
      let err_body =
        create_unprocessable_error(errors)
        |> json.to_string_tree

      wisp.unprocessable_entity()
      |> wisp.json_body(err_body)
    }
  }
}
