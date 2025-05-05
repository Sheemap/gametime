import gleam/erlang/process.{type Subject}
import gleam/otp/supervisor

// The "channel" is where we will send new ClockEvents, and receive new ClockEvents
// On sending, we will expect the websocket, and queue connection to forward on the clock event
// 
// We will only receive from queues, so not a complexity to worry about rn. But we will receive from a queue, and then forward with websocket

// This is the type you will RECEIVE FROM the channel
pub type ChannelResponse {
  // The child can send a new subject back in order for bidirectional communication
  ChildSubject(Subject(ChannelRequest))
}

// This is the type you can SEND TO the channel
pub type ChannelRequest {
  Free(ChannelResponse)
}

pub fn start() -> Subject(ChannelResponse) {
  // TODO: create a supervisor, provided in gleam/otp
  // let channel = supervisor.start(supervisor.Spec())
  let channel = process.new_subject()

  // Just return?
  // TODO: what
  // figure out
  channel
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
