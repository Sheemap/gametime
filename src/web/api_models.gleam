import clock/clock
import gleam/dynamic/decode
import gleam/float
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string_tree
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}
import lobby/lobby
import web/models.{CreateLobbyConfigRequest, CreateSeat}

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
    increment_seconds: Option(Int),
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
      use increment_seconds <- decode.field(
        "increment_seconds",
        decode.optional(decode.int),
      )
      decode.success(Seat(name, initial_seconds, increment_seconds))
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
      let clock_state = clock.check_clock(s.clock)

      // If active_since is None, then ends_at will also be None
      let ends_at =
        clock_state.active_since
        |> option.map(fn(_) {
          timestamp.add(timestamp.system_time(), clock_state.remaining_duration)
        })

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
  |> json.to_string_tree
}
