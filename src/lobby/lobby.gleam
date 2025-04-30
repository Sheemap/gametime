import clock/clock
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type Seat {
  Seat(id: String, name: Option(String), clock: clock.Clock)
}

pub type Lobby {
  Lobby(id: String, name: String, seats: List(Seat))
}

pub type AdvanceLobbyError {
  NoActiveSeat
}

pub fn advance(lobby: Lobby) -> Result(Lobby, AdvanceLobbyError) {
  // TODO: Allow specifying a sort of "strategy" in the lobby
  // This current implementation is hardcoded to just push through the list
  let active_seat_index =
    lobby.seats
    |> list.index_fold(-1, fn(location: Int, seat: Seat, cur_index: Int) {
      let clock_state = clock.check_clock(seat.clock)

      case clock_state.active_since {
        Some(_) -> cur_index
        None -> location
      }
    })

  case active_seat_index {
    // No active seat
    -1 -> Error(NoActiveSeat)
    _ -> {
      let next_seat_index =
        wrap_index(active_seat_index + 1, list.length(lobby.seats))

      // Map over the seats to get the new ones.
      // Need to stop the current clock, and start the next
      let seats =
        lobby.seats
        |> list.index_map(fn(s, index) {
          case index {
            _ if active_seat_index == index ->
              s.clock |> clock.stop_clock |> Seat(s.id, s.name, _)
            _ if next_seat_index == index ->
              s.clock |> clock.start_clock |> Seat(s.id, s.name, _)
            _ -> s
          }
        })

      Ok(Lobby(lobby.id, lobby.name, seats))
    }
  }
}

/// Figure out next clock index. If it goes over length, wrap around to 0
fn wrap_index(desired, length) {
  case desired > length {
    True -> 0
    False -> desired
  }
}
