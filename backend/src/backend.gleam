import api/router
import db/db
import gleam/erlang
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/json
import gleam/option.{Some}
import gleam/otp/actor
import gleam/time/duration
import lobby/messaging
import mist.{type Connection, type ResponseData}
import radiate
import sqlight
import wisp
import wisp/wisp_mist

pub type AddTimeError {
  MissingArgument
  InvalidArgument
}

pub type UserAction {
  Unknown
  InputError(erlang.GetLineError)
  Quit
  Check
  Start
  Stop
  ShowEvents
  Add(Result(duration.Duration, AddTimeError))
}

pub fn main() {
  let _ =
    radiate.new()
    |> radiate.add_dir("src")
    |> radiate.start()

  io.println("Hello from gametime!")
  // action_loop([])
  //

  let websocket_subject = messaging.start()

  use conn <- sqlight.with_connection("gametime.db")
  let assert Ok(_) = db.init_db(conn)

  let web_context =
    router.Context(db: db.Context(conn:), ws_hub: websocket_subject)

  // This sets the logger to print INFO level logs, and other sensible defaults
  // for a web application.
  wisp.configure_logger()

  // Start the Mist web server.
  let assert Ok(_) =
    misty_handler(web_context)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}

pub type WsMessage {
  Broadcast(String)
}

fn misty_handler(web_context: router.Context) {
  fn(req: Request(Connection)) -> Response(ResponseData) {
    let secret_key_base = wisp.random_string(64)
    case request.path_segments(req) {
      ["api", "v1", "lobby", lobby_id, "ws"] -> {
        let asdf =
          mist.websocket(
            request: req,
            on_init: fn(conn) {
              let subject = process.new_subject()
              process.send(
                web_context.ws_hub,
                messaging.StoreWebsocket(lobby_id, subject),
              )

              let selector =
                process.new_selector()
                |> process.selecting(subject, fn(x) {
                  x |> json.to_string |> Broadcast
                })

              #(conn, Some(selector))
            },
            on_close: fn(_conn) { io.println("goodbye!") },
            handler: handle_ws_message,
          )

        asdf
      }
      _ ->
        wisp_mist.handler(
          fn(r) { router.handle_request(r, web_context) },
          secret_key_base,
        )(req)
    }
  }
}

fn handle_ws_message(state, conn, message) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(state)
    }
    mist.Text(_) | mist.Binary(_) -> {
      actor.continue(state)
    }
    mist.Custom(Broadcast(val)) -> {
      let _ = mist.send_text_frame(conn, val)
      actor.continue(state)
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}
// fn action_loop(events ) {
//   let x =
//     erlang.get_line(
//       "Whats your action? [q]uit [c]heck [s]tart [S]top [a]dd [e]vents\n",
//     )
//   let action = case x {
//     Ok(val) -> determine_action(val)
//     Error(e) -> InputError(e)
//   }
//   case action {
//     Quit -> io.println("Bye bye!")
//     Unknown -> {
//       io.println("Idk what this is! Try again?")
//       action_loop(events)
//     }
//     InputError(_) -> {
//       io.println("Uh oh! We got an error! Try again?")
//       action_loop(events)
//     }
//     Start -> clock.start_clock(events) |> action_loop()
//     Stop -> clock.stop_clock(events) |> action_loop()
//     Add(val) ->
//       case val {
//         Ok(dur) -> clock.add_time(events, dur) |> action_loop()
//         Error(e) ->
//           case e {
//             MissingArgument -> {
//               io.println(
//                 "Missing add duration! Usage: `a {seconds}`, `a 10`, `a -3`",
//               )
//               action_loop(events)
//             }
//             InvalidArgument -> {
//               io.println("Invalid add duration! Must be a valid integer")
//               action_loop(events)
//             }
//           }
//       }
//     Check -> {
//       echo clock.check_clock(events)
//       action_loop(events)
//     }
//     ShowEvents -> {
//       echo list.reverse(events)
//       action_loop(events)
//     }
//   }
// }

// fn determine_action(in) {
//   case string.trim(in) {
//     "q" -> Quit
//     "c" -> Check
//     "e" -> ShowEvents
//     "s" -> Start
//     "S" -> Stop
//     "a" -> Add(Error(MissingArgument))
//     "a " <> seconds -> get_duration(seconds)
//     _ -> Unknown
//   }
// }

// fn get_duration(in) {
//   case int.parse(in) {
//     Ok(val) -> Add(Ok(duration.seconds(val)))
//     Error(_) -> Add(Error(InvalidArgument))
//   }
// }
