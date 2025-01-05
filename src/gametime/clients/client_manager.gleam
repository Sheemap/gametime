import gametime/model.{type Room}
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result

pub type ClientMessage {
  Heartbeat
  RoomUpdate(room: Room)
}

pub type ClientManagementMessage {
  Connect(id: String, room_id: String, Subject(ClientMessage))
  Disconnect(id: String, room_id: String)
  GetAllClients(subject: Subject(Dict(String, Subject(ClientMessage))))
  GetRoom(
    room_id: String,
    subject: Subject(Option(Dict(String, Subject(ClientMessage)))),
  )
  RoomChanged(room: Room)
}

pub fn init() {
  let assert Ok(subject) = actor.start(dict.new(), loop)
  process.start(fn() { heartbeat(subject) }, False)
  subject
}

fn loop(
  msg: ClientManagementMessage,
  state: Dict(String, Dict(String, Subject(ClientMessage))),
) -> actor.Next(
  ClientManagementMessage,
  Dict(String, Dict(String, Subject(ClientMessage))),
) {
  case msg {
    Connect(id, room_id, subject) -> {
      let new_state =
        state
        |> dict.get(room_id)
        |> result.unwrap(dict.new()) // Unwrap the result, or initialize a new empty dict
        |> dict.insert(id, subject) // Insert our subject into the dict
        |> dict.insert(state, room_id, _) // Update the original state

      actor.continue(new_state)
    }
    Disconnect(id, room_id) -> {
      let new_state =
        state
        |> dict.get(room_id) // Get the room dict
        |> result.map(dict.delete(_, id)) // If got a result, delete this ID from it
        |> result.map(dict.insert(state, room_id, _)) // If success, update state with our new room
        |> result.unwrap(state) // Unwrap the result, or revert back to original state if error

      actor.continue(new_state)
    }
    GetAllClients(subject) -> {
      let all_clients =
        dict.values(state)
        |> list.fold(dict.new(), dict.merge)

      process.send(subject, all_clients)

      actor.continue(state)
    }
    GetRoom(room_id, subject) -> {
      state
      |> dict.get(room_id)
      |> option.from_result
      |> process.send(subject, _)

      actor.continue(state)
    }
    RoomChanged(room) -> {
      // TODO: Get current room state, broadcast to clients
      // Get from DB (Or maybe its passed through this message?)
      // Broadcast new state to all clients in the room

      case state |> dict.get(room.id) {
        Ok(room_clients) -> send_all(room_clients, RoomUpdate(room))
        Error(_) -> Nil
      }

      actor.continue(state)
    }
  }
}

fn send_all(
  clients: Dict(String, Subject(ClientMessage)),
  message: ClientMessage,
) {
  clients
  |> dict.each(fn(_, subject) {
    subject
    |> process.send(message)
  })
}

fn heartbeat(client_manager: Subject(ClientManagementMessage)) -> Nil {
  // Wait 1s
  process.sleep(1000)

  // Get current clients
  let subject = process.new_subject()
  process.send(client_manager, GetAllClients(subject))
  let assert Ok(client_dict) = process.receive(subject, 500)

  // Send heartbeat to all clients
  client_dict
  |> send_all(Heartbeat)

  // Loop
  heartbeat(client_manager)
}
