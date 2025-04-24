import gleam/option.{type Option}

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
