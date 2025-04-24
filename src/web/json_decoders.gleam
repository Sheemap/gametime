import gleam/dynamic/decode
import gleam/json
import web/models.{CreateLobbyConfigRequest, CreateSeat}

pub fn create_lobby_config_request(json_string) {
  let decoder = {
    let seat_decoder = {
      use name <- decode.field("name", decode.optional(decode.string))
      use initial_seconds <- decode.field("initial_seconds", decode.int)
      use increment_seconds <- decode.field(
        "increment_seconds",
        decode.optional(decode.int),
      )
      decode.success(CreateSeat(name, initial_seconds, increment_seconds))
    }

    use name <- decode.field("name", decode.string)
    use seats <- decode.field("seats", decode.list(seat_decoder))
    decode.success(CreateLobbyConfigRequest(name, seats))
  }
  json.parse(from: json_string, using: decoder)
}
