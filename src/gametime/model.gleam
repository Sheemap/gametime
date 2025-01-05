import birl/duration.{type Duration}
import gleam/option.{type Option}

pub type Clock {
  Clock(
    id: String,
    label: String,
    increment: Duration,
    initial_value: Duration,
    current_value: Duration,
  )
}

pub type Room {
  Room(id: String, clocks: List(Clock), active_clock: Option(String))
}
