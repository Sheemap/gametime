import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json
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

/// Create's a lobby
fn create_lobby(req) {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_json(req)
  echo body
  let json_str = {
    let json_str = decode.run(body, decode.string)
    case json_str {
      Ok(str) -> str
      Error(e) -> "{}"
    }
  }
  echo json_str

  let model = json_decoders.create_lobby_config_request(json_str)
  echo model

  let resp = string_tree.from_string("{\"lobbyId\": \"ID yay!\"}")

  wisp.ok()
  |> wisp.json_body(resp)
}
