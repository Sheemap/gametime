import gametime/context
import gametime/router
import gleam/erlang/process
import gleam/result
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)
  let ctx = context.init()
  let assert Ok(_) =
    router.handle_request(_, ctx, secret_key_base)
    |> mist.new()
    |> mist.bind("0.0.0.0")
    |> mist.port(5001)
    |> mist.start_http()

  process.sleep_forever()
}
