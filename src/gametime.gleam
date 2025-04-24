import clock/clock
import gleam/erlang
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/time/duration
import mist
import web/router
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
  io.println("Hello from gametime!")
  // action_loop([])

  // This sets the logger to print INFO level logs, and other sensible defaults
  // for a web application.
  wisp.configure_logger()

  // TODO: Dont regenerate this every run, load from DB or so
  let secret_key_base = wisp.random_string(64)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp_mist.handler(router.handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}

fn action_loop(events) {
  let x =
    erlang.get_line(
      "Whats your action? [q]uit [c]heck [s]tart [S]top [a]dd [e]vents\n",
    )
  let action = case x {
    Ok(val) -> determine_action(val)
    Error(e) -> InputError(e)
  }
  case action {
    Quit -> io.println("Bye bye!")
    Unknown -> {
      io.println("Idk what this is! Try again?")
      action_loop(events)
    }
    InputError(_) -> {
      io.println("Uh oh! We got an error! Try again?")
      action_loop(events)
    }
    Start -> clock.start_clock(events) |> action_loop()
    Stop -> clock.stop_clock(events) |> action_loop()
    Add(val) ->
      case val {
        Ok(dur) -> clock.add_time(events, dur) |> action_loop()
        Error(e) ->
          case e {
            MissingArgument -> {
              io.println(
                "Missing add duration! Usage: `a {seconds}`, `a 10`, `a -3`",
              )
              action_loop(events)
            }
            InvalidArgument -> {
              io.println("Invalid add duration! Must be a valid integer")
              action_loop(events)
            }
          }
      }
    Check -> {
      echo clock.check_clock(events)
      action_loop(events)
    }
    ShowEvents -> {
      echo list.reverse(events)
      action_loop(events)
    }
  }
}

fn determine_action(in) {
  case string.trim(in) {
    "q" -> Quit
    "c" -> Check
    "e" -> ShowEvents
    "s" -> Start
    "S" -> Stop
    "a" -> Add(Error(MissingArgument))
    "a " <> seconds -> get_duration(seconds)
    _ -> Unknown
  }
}

fn get_duration(in) {
  case int.parse(in) {
    Ok(val) -> Add(Ok(duration.seconds(val)))
    Error(_) -> Add(Error(InvalidArgument))
  }
}
