import clock/clock.{type Clock}
import gleam/option.{type Option}
import gleam/time/duration

pub type Seat {
  Seat(
    id: String,
    name: Option(String),
    increment: Option(duration.Duration),
    clock: Clock,
  )
}

pub type LobbyConfig {
  LobbyConfig(id: String, name: String, seats: List(Seat))
}
