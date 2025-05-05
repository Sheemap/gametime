import gleam/string_tree
import wisp

pub fn initial(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  // Log information about the request and response.
  use <- wisp.log_request(req)

  // Return a default 500 response if the request handler crashes.
  use <- wisp.rescue_crashes

  // Rewrite HEAD requests to GET requests and return an empty body.
  use req <- wisp.handle_head(req)

  // Handle the request!
  handle_request(req)
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
