import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string_tree
import wisp

/// Returns a bad request 400 HTTP error
/// The message param is passed through to the "detail" json field
pub fn bad_request(detail: Option(String)) {
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
