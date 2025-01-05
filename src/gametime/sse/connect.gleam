import birl/duration
import gametime/clients/client_manager.{
  type ClientManagementMessage, type ClientMessage, Connect, Disconnect,
  Heartbeat, RoomUpdate,
}
import gametime/context.{type Context}
import gametime/model.{type Room}
import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/process.{Normal}
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io.{debug}
import gleam/json
import gleam/option.{None, Some}
import gleam/otp/actor.{type InitResult, type Next, Continue, Ready}
import gleam/string_tree
import mist.{type Connection, type ResponseData, type SSEConnection}
import sqlight
import youid/uuid.{type Uuid}

pub fn handle(
  req: Request(Connection),
  ctx: Context,
  room_id: String,
) -> Response(ResponseData) {
  let subject = process.new_subject()
  process.send(ctx.client_manager, client_manager.GetRoom(room_id, subject))

  case process.receive(subject, 500) {
    Error(_) ->
      response.new(502) |> response.set_body(mist.Bytes(bytes_tree.new()))
    Ok(room_option) ->
      case room_option {
        None ->
          response.new(404) |> response.set_body(mist.Bytes(bytes_tree.new()))
        Some(_) -> {
          let device_id = uuid.v4_string()
          mist.server_sent_events(
            req,
            initial_response(device_id),
            fn() { init(ctx, device_id, room_id) },
            fn(msg, conn, _) { loop(ctx, device_id, room_id, msg, conn) },
          )
        }
      }
  }
}

fn initial_response(id: String) -> Response(String) {
  response.new(200)
  |> response.set_header(
    "Set-Cookie",
    "sessionid="
      <> id
    |> bit_array.from_string()
    |> bit_array.base64_encode(False)
      <> "; Path=/; SameSite=Strict",
  )
}

fn init(
  ctx: Context,
  device_id: String,
  room_id: String,
) -> InitResult(Nil, ClientMessage) {
  let subject = process.new_subject()
  process.send(ctx.client_manager, client_manager.GetRoom(room_id, subject))

  case process.receive(subject, 500) {
    Error(_) -> actor.Failed("Error connecting to room")
    Ok(room) ->
      case room {
        option.None -> actor.Failed("Room does not exist")
        option.Some(_) -> {
          let subject = process.new_subject()
          process.send(ctx.client_manager, Connect(device_id, room_id, subject))

          Ready(
            Nil,
            process.new_selector()
              |> process.selecting(subject, function.identity),
          )
        }
      }
  }
}

fn json_encode_clock(clock: model.Clock) {
  let current_value =
    duration.blur_to(clock.current_value, duration.MilliSecond)
  json.object([
    #("id", json.string(clock.id)),
    #("label", json.string(clock.label)),
    #("current_value", json.int(current_value)),
  ])
}

fn loop(
  ctx: Context,
  id: String,
  room_id: String,
  msg: ClientMessage,
  connection: SSEConnection,
) -> Next(ClientMessage, Nil) {
  case msg {
    RoomUpdate(new_room) -> {
      let json_encoded_room =
        json.object([
          #("id", json.string(new_room.id)),
          #("active_clock", json.nullable(new_room.active_clock, json.string)),
          #("clocks", json.array(new_room.clocks, json_encode_clock)),
        ])
        |> json.to_string_tree()

      debug("buh")
      debug(json_encoded_room)
      case
        mist.send_event(
          connection,
          mist.event(json_encoded_room)
            |> mist.event_name("roomUpdate"),
        )
      {
        Ok(_) -> Continue(Nil, None)
        Error(_) -> {
          process.send(ctx.client_manager, Disconnect(id, room_id))
          actor.Stop(Normal)
        }
      }

      Continue(Nil, None)
    }
    Heartbeat -> {
      case
        mist.send_event(
          connection,
          mist.event(string_tree.new())
            |> mist.event_name("heartbeat"),
        )
      {
        Ok(_) -> Continue(Nil, None)
        Error(_) -> {
          process.send(ctx.client_manager, Disconnect(id, room_id))
          actor.Stop(Normal)
        }
      }
    }
  }
}
