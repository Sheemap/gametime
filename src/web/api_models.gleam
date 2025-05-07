import clock/clock
import gleam/dynamic/decode
import gleam/float
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}
import lobby/lobby

/// errors
pub fn encode_unprocessable_entity_response(errors: List(decode.DecodeError)) {
  errors
  |> list.map(fn(err) {
    json.object([
      #("expected", json.string(err.expected)),
      #("found", json.string(err.found)),
      #("path", json.array(err.path, json.string)),
    ])
  })
  |> json.preprocessed_array
  |> json.to_string_tree
}

/// create-lobby stuff
pub type Seat {
  Seat(
    name: Option(String),
    initial_seconds: Int,
    // TODO: Implement increment
    // increment_seconds: Option(Int),
  )
}

pub type CreateLobbyRequest {
  CreateLobbyRequest(name: String, seats: List(Seat))
}

pub type CreateLobbyResponse {
  CreateLobbyResponse(lobby_id: String)
}

pub fn decode_create_lobby_request(body) {
  let decoder = {
    let seat_decoder = {
      use name <- decode.field("name", decode.optional(decode.string))
      use initial_seconds <- decode.field("initial_seconds", decode.int)
      decode.success(Seat(name, initial_seconds))
    }

    use name <- decode.field("name", decode.string)
    use seats <- decode.field("seats", decode.list(seat_decoder))
    decode.success(CreateLobbyRequest(name, seats))
  }

  decode.run(body, decoder)
}

pub fn encode_create_lobby_response(response: CreateLobbyResponse) {
  json.object([#("lobby_id", json.string(response.lobby_id))])
  |> json.to_string_tree
}

pub fn map_create_request_to_lobby(model: CreateLobbyRequest) {
  let seats =
    model.seats
    |> list.map(fn(s) {
      let #(new_clock, _) =
        clock.add_time([], duration.seconds(s.initial_seconds))

      lobby.Seat(
        id: lobby.generate_id(lobby.SeatId),
        name: s.name,
        clock: new_clock,
      )
    })

  lobby.Lobby(id: lobby.generate_id(lobby.LobbyId), name: model.name, seats:)
}

/// get-lobby stuff
pub type LobbyClock {
  LobbyClock(remaining_duration: Duration, ends_at: Option(Timestamp))
}

pub type LobbySeat {
  LobbySeat(id: String, name: Option(String), clock: LobbyClock)
}

pub type GetLobbyResponse {
  GetLobbyResponse(id: String, name: String, seats: List(LobbySeat))
}

pub fn map_lobby_to_response(lobby: lobby.Lobby) -> GetLobbyResponse {
  let seats =
    lobby.seats
    |> list.map(fn(s) {
      // To map the DB lobby to the response, we need to compute two things:
      //   - The remaining duration of each clock
      //   - If the clock is running, what time the clock will end

      // With the seat's clock events, figure out the current clock state
      let clock_state = clock.check_clock(s.clock)

      let ends_at = {
        // If active since is None, that means the clock is not running,
        // and there is no ends_at value to be calculated.
        case option.is_none(clock_state.active_since) {
          True -> None
          False ->
            timestamp.add(
              timestamp.system_time(),
              clock_state.remaining_duration,
            )
            |> Some
        }
      }

      // Finally map that clock back into a LobbyClock, and map the result into a LobbySeat
      LobbyClock(remaining_duration: clock_state.remaining_duration, ends_at:)
      |> LobbySeat(id: s.id, name: s.name, clock: _)
    })

  GetLobbyResponse(id: lobby.id, name: lobby.name, seats:)
}

pub fn encode_get_lobby_response(response: GetLobbyResponse) {
  let seats = {
    response.seats
    |> list.map(fn(seat) {
      let remaining_duration =
        seat.clock.remaining_duration
        |> duration.to_seconds()
        |> float.to_precision(3)

      let ends_at =
        seat.clock.ends_at
        |> option.map(timestamp.to_unix_seconds)
        |> option.map(float.to_precision(_, 3))

      let clock = {
        [
          #("remaining_duration", json.float(remaining_duration)),
          #("ends_at", json.nullable(ends_at, json.float)),
        ]
      }

      json.object([
        #("id", json.string(seat.id)),
        #("name", json.nullable(seat.name, json.string)),
        #("clock", json.object(clock)),
      ])
    })
  }

  json.object([
    #("id", json.string(response.id)),
    #("name", json.string(response.name)),
    #("seats", json.preprocessed_array(seats)),
  ])
}
