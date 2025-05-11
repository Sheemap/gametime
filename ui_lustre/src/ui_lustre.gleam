import gleam/float
import gleam/int
import gleam/io
import gleam/time/calendar
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}
import lustre
import lustre/attribute.{attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg

// MAIN ------------------------------------------------------------------------

pub fn main() {
  // Both getting the user's timezone and the current time are side effects, but
  // we can perform them before our app starts and create the initial model right
  // away.
  let timezone = calendar.local_offset()
  let now = timestamp.system_time()
  let model = Model(timezone:, time: now)

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", model)

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(timezone: Duration, time: Timestamp)
}

fn init(model: Model) -> #(Model, Effect(Msg)) {
  // Calling the `tick` effect immediately on init kicks off our clock!
  #(model, tick())
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  ClockTickedForward
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ClockTickedForward -> #(
      Model(..model, time: timestamp.add(model.time, duration.seconds(1))),
      // Every tick of the clock, we schedule another one to happen in 1 second.
      // If our app wants to stop the clock, it can just stop returning the
      // effect.
      tick(),
    )
  }
}

fn tick() -> Effect(Msg) {
  use dispatch <- effect.from
  use <- set_timeout(1000)

  dispatch(ClockTickedForward)
}

/// when writing custom effects that need ffi, it's common practice to define the
/// externals separate to the effect itself.
@external(javascript, "./ui_lustre.ffi.mjs", "set_timeout")
fn set_timeout(_delay: Int, _cb: fn() -> a) -> Nil {
  // It's good practice to provide a fallback for side effects that rely on FFI
  // where possible. This means your app can run - without the side effect - in
  // environments other than the browser.
  Nil
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  html.div(
    [attribute.class("w-screen h-screen flex justify-center items-center")],
    [html.text("Hia :)")],
  )
}
