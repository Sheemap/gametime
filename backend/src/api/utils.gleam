import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string_tree
import wisp.{type Request, type Response}

pub fn require_json(
  request: Request,
  next: fn(decode.Dynamic) -> Response,
) -> Response {
  use <- wisp.require_content_type(request, "application/json")
  use body <- wisp.require_string_body(request)

  case json.decode(body, Ok) {
    Ok(r) -> next(r)
    Error(_) -> bad_request(Some("failed to decode json"))
  }
}

/// Returns a bad request 400 HTTP error
/// The message param is passed through to the "detail" json field
pub fn bad_request(detail: Option(String)) -> Response {
  case detail {
    None -> wisp.bad_request()
    Some(msg) -> {
      let body =
        json.object([#("detail", json.string(msg))]) |> json.to_string_tree()

      wisp.bad_request() |> wisp.json_body(body)
    }
  }
}

pub fn require_predicate(func: fn() -> Bool, msg: String, callback) {
  case func() {
    True -> callback()
    False ->
      wisp.bad_request()
      |> wisp.json_body(string_tree.from_string(
        "{\"detail\": \"" <> msg <> "\"}",
      ))
  }
}
