import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/otp/actor
import gleam/time/timestamp

// The "channel" is where we will send new ClockEvents, and receive new ClockEvents
// On sending, we will expect the websocket, and queue connection to forward on the clock event
// 
// We will only receive from queues, so not a complexity to worry about rn. But we will receive from a queue, and then forward with websocket

// This is the type you will RECEIVE FROM the channel
pub type ChannelResponse {
  // When we store websocket, we return a new subject from within that new beam thread.
  // That way we can send shit directly to an individual websocket
  ChildSubject(Subject(ChannelRequest))
}

pub type LobbyMessage {
  LobbyMessage(msg_type: String, content: json.Json)
}

// This is the type you can SEND TO the channel
pub type ChannelRequest {
  Start
  StoreWebsocket(String, Subject(json.Json))
  Emit(String, LobbyMessage)
}

pub fn start() -> Subject(ChannelRequest) {
  let assert Ok(actor) =
    actor.start_spec(
      actor.Spec(
        init: fn() { actor.Ready([], process.new_selector()) },
        init_timeout: 10,
        loop: fn(msg: ChannelRequest, state) {
          case msg {
            Start -> actor.Continue(state, None)
            StoreWebsocket(lobby_id, websocket) -> {
              actor.Continue([#(lobby_id, websocket), ..state], None)
            }
            Emit(lobby_id, lobby_msg) -> {
              let now =
                timestamp.system_time()
                |> timestamp.to_unix_seconds()
                |> float.to_precision(3)

              let res_json =
                json.object([
                  #("occurred_at", json.float(now)),
                  #("msg_type", json.string(lobby_msg.msg_type)),
                  #("content", lobby_msg.content),
                ])

              state
              |> list.filter(fn(state_item) { state_item.0 == lobby_id })
              |> list.each(fn(state_item) {
                process.send(state_item.1, res_json)
              })

              actor.Continue(state, None)
            }
          }
        },
      ),
    )
  actor
}
// TODO: Implement this
//
// AC:
// Allow the API endpoints to trigger sending events out to all relevant websocket connections
// 
// To do this, we can have pass in a subject to the router code.
// That subject can have two things sent to it,
// Seat/clock events
// And websocket connections
// 
// Then this supervisor can handle each connection in a seperate BEAM thread.
// Allowing us to handle closes and unexpected things more easily.
