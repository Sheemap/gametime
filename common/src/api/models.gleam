import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}

pub type CreateSeat {
  CreateSeat(
    name: Option(String),
    initial_seconds: Int,
    increment_seconds: Option(Int),
  )
}

pub type CreateLobbyConfigRequest {
  CreateLobbyConfigRequest(name: String, seats: List(CreateSeat))
}

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

pub fn decode_create_lobby_request(
  body: decode.Dynamic,
) -> Result(CreateLobbyRequest, List(decode.DecodeError)) {
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

/// get-lobby stuff
pub type LobbyClock {
  LobbyClock(remaining_duration: Duration, ends_at: Option(Timestamp))
}

pub fn lobby_clock_decoder() -> decode.Decoder(LobbyClock) {
  use float_duration <- decode.field("remaining_duration", decode.float)
  use float_ends_at <- decode.field("ends_at", decode.optional(decode.float))

  let remaining_duration =
    float_duration
    |> float.multiply(1000.0)
    |> float.truncate
    |> duration.milliseconds

  // The timestamp is sent as unix timestamp in seconds. With 3 digits of precision
  // We want to ultimately get a timestamp at that exact time
  let ends_at =
    float_ends_at
    // First convert the seconds into milliseconds
    |> option.map(float.multiply(_, 1000.0))
    // Then truncate any remaining decimals (There shouldnt be any)
    |> option.map(float.truncate)
    // And finally, get the timestamp
    |> option.map(fn(ends_at_millies) {
      let seconds = ends_at_millies / 1000
      let nanosecs = int.multiply(ends_at_millies % 1000, 1_000_000)

      timestamp.from_unix_seconds_and_nanoseconds(seconds, nanosecs)
    })

  decode.success(LobbyClock(remaining_duration:, ends_at:))
}

pub type LobbySeat {
  LobbySeat(id: String, name: Option(String), clock: LobbyClock)
}

pub fn lobby_seat_decoder() -> decode.Decoder(LobbySeat) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.optional(decode.string))
  use clock <- decode.field("clock", lobby_clock_decoder())
  decode.success(LobbySeat(id:, name:, clock:))
}

pub type GetLobbyResponse {
  GetLobbyResponse(id: String, name: String, seats: List(LobbySeat))
}

pub fn get_lobby_response_decoder() -> decode.Decoder(GetLobbyResponse) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use seats <- decode.field("seats", decode.list(lobby_seat_decoder()))
  decode.success(GetLobbyResponse(id:, name:, seats:))
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
