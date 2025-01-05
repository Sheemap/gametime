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
  CreateRoom(id: String)
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
      let room_dict =
        state
        |> dict.get(room_id)

      let new_rooms = {
        case room_dict {
          Ok(rooms) -> rooms |> dict.insert(id, subject)
          Error(_) -> dict.new() |> dict.insert(id, subject)
        }
      }

      let new_state =
        state
        |> dict.insert(room_id, new_rooms)

      actor.continue(new_state)
    }
    Disconnect(id, room_id) -> {
      let room_dict =
        state
        |> dict.get(room_id)
        |> result.map(dict.delete(_, id))

      let new_state = {
        case room_dict {
          Ok(rooms) -> state |> dict.insert(room_id, rooms)
          Error(_) -> state
        }
      }

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
    CreateRoom(room_id) -> {
      state |> dict.insert(room_id, dict.new()) |> actor.continue
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
