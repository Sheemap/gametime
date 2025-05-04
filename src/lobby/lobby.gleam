import clock/clock
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/calendar

pub type TurnStrategy {
  Clockwise
}

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
  // TODO: Load strategy from the Lobby
  let strategy = Clockwise
  case strategy {
    Clockwise -> advance_clockwise(lobby)
  }
}

fn advance_clockwise(lobby: Lobby) {
  // Figure out the index of the current seat
  let active_seat_index =
    lobby.seats
    |> list.index_fold(-1, fn(location: Int, seat: Seat, cur_index: Int) {
      let clock_state = clock.check_clock(seat.clock)

      // If this clock is active, update the result value with the index!
      // Otherwise just pass the input value on through
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

pub type CanAdvanceLobbyError {
  SeatNotFound
}

/// Answers the question, "Is the lobby in such a state that the seat with an ID of seat_id would be allowed to advance the turns"
/// Or in other words, "Is it this players turn?"
/// 
/// An Error result gives a message as to what failed
pub fn can_seat_advance_lobby(
  lobby_strategy: TurnStrategy,
  lobby_state: Lobby,
  seat_id: String,
) -> Result(Bool, CanAdvanceLobbyError) {
  case lobby_strategy {
    Clockwise -> can_advance_clockwise(lobby_state, seat_id)
  }
}

/// If the seat is currently active, the answer is yes
/// Otherwise the answer is no
///
/// An error only occurs on a non-existant seat_id
fn can_advance_clockwise(lobby: Lobby, seat_id: String) {
  lobby.seats
  // Find by ID
  |> list.find(fn(s) { s.id == seat_id })
  // If we got an error, means we did not find the seat
  // Lets give a more meaningful error than Nil to our code ppl above
  |> result.replace_error(SeatNotFound)
  // Map the inner value of the result to ClockState
  |> result.map(fn(s) { clock.check_clock(s.clock) })
  // Map the result to a bool with True representing a running clock, and False a stopped one
  |> result.map(fn(c) { option.is_some(c.active_since) })
}

/// Figure out next clock index. If it goes over length, wrap around to 0
fn wrap_index(desired, length) {
  case desired > length {
    True -> 0
    False -> desired
  }
}
