import gametime/api
import gametime/context.{type Context}
import gametime/sse/connect
import gleam/erlang/process
import gleam/http.{Get}
import gleam/http/request
import gleam/http/response
import gleam/option
import gleam/result
import mist
import simplifile
import wisp.{type Request, type Response}
import wisp/wisp_mist

fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  let assert Ok(priv_dir) = wisp.priv_directory("gametime")
  use <- wisp.serve_static(req, "/", priv_dir <> "/static")

  handle_request(req)
}

pub fn handle_request(
  req: request.Request(mist.Connection),
  ctx: Context,
  secret_key_base: String,
) -> response.Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["sse", "connect", room_id] -> connect.handle(req, ctx, room_id)
    _ -> wisp_mist.handler(handle_request_wisp(_, ctx), secret_key_base)(req)
  }
}

fn handle_request_wisp(req: Request, ctx: Context) -> Response {
  use req <- middleware(req)
  case wisp.path_segments(req) {
    ["api", "v1", "create-room"] -> api.create_room(req, ctx)
    ["api", "v1", "press-clock", clock_id] ->
      api.press_clock(req, ctx, clock_id)
    _ -> wisp.not_found() |> wisp.string_body("Not found")
  }
}
