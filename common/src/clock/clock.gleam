//// The clock module provides functions for manipulating "Clocks"
//// Clocks are timers have a time value, and a state of on/off. As long as the clock is in the on state, the time will decrease. Like one half of a chess clock
////
//// Internally Clocks are represented as List(ClockEvent), which is a list of every event that has occured, and the timestamp.
//// With this event data, we can compute the ClockState. Which is a snapshot of how much time is remaining, and what time the clock was started (if its running).
////

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/time/duration
import gleam/time/timestamp

/// A Clock is a list of ClockEvents which can be aggregated together to determine the ClockState
pub type Clock =
  List(ClockEvent)

/// A snapshot in time of a clock's state
pub type ClockState {
  ClockState(
    remaining_duration: duration.Duration,
    active_since: option.Option(timestamp.Timestamp),
  )
}

/// An interaction with the clock
pub type ClockEvent {
  Start(timestamp.Timestamp)
  Stop(timestamp.Timestamp)
  Add(timestamp.Timestamp, duration.Duration)
}

/// Prepends the Start event to the clock
/// Returning the new event if it did so
pub fn start_clock(clock: Clock) -> #(Clock, Option(ClockEvent)) {
  case check_clock(clock).active_since {
    // Clock is already running, dont add anything
    Some(_) -> #(clock, None)
    None -> {
      let event = Start(timestamp.system_time())
      #([event, ..clock], Some(event))
    }
  }
}

/// Prepends the Stop event to the clock
/// Returning the new event if it did so
pub fn stop_clock(clock) -> #(Clock, Option(ClockEvent)) {
  case check_clock(clock).active_since {
    // Clock is already stopped, dont add anything
    None -> #(clock, None)
    Some(_) -> {
      let event = Stop(timestamp.system_time())
      #([event, ..clock], Some(event))
    }
  }
}

/// Prepends the Add event to the clock
/// Returning the new event after doing so
///
/// To subtract time, add a negative duration
pub fn add_time(clock, duration: duration.Duration) -> #(Clock, ClockEvent) {
  let event = Add(timestamp.system_time(), duration)
  #([event, ..clock], event)
}

/// Figure out the current clock state
pub fn check_clock(events: Clock) {
  let base_state = ClockState(duration.seconds(0), option.None)
  let sorted = list.sort(events, event_compare)
  get_clock_state(base_state, sorted)
}

fn get_clock_state(state: ClockState, events) -> ClockState {
  case events {
    [] -> {
      case state.active_since {
        None -> state
        Some(active_since) ->
          active_since
          // active_since - now, should be negative duration
          |> timestamp.difference(timestamp.system_time(), _)
          // figure out remaining_duration
          |> duration.add(state.remaining_duration)
          // construct new state
          |> ClockState(state.active_since)
      }
    }
    [event, ..events_remainder] -> {
      case event {
        Start(time) -> {
          // We only want to update the active_since value if the event input is older than the current active_since
          let active_since: timestamp.Timestamp = case state.active_since {
            option.Some(val) -> val
            option.None -> {
              let assert Ok(ts) =
                // So far in the future it might as well never happen
                timestamp.parse_rfc3339("4000-01-01T00:00:00Z")
              ts
            }
          }
          case timestamp.compare(time, active_since) {
            order.Lt ->
              get_clock_state(
                ClockState(state.remaining_duration, option.Some(time)),
                events_remainder,
              )
            _ -> get_clock_state(state, events_remainder)
          }
        }
        Stop(time) ->
          case state.active_since {
            None -> {
              get_clock_state(state, events_remainder)
            }
            Some(active_since) ->
              active_since
              // time - active_since, should be negative duration
              |> timestamp.difference(time, _)
              // figure out remaining_duration
              |> duration.add(state.remaining_duration)
              // construct new state
              |> ClockState(None)
              |> get_clock_state(events_remainder)
          }
        Add(_, dur) ->
          dur
          |> duration.add(state.remaining_duration)
          |> ClockState(state.active_since)
          |> get_clock_state(events_remainder)
      }
    }
  }
}

/// Compares the timestamps of two clock events
pub fn event_compare(left, right) {
  let occurred_at = fn(event) {
    case event {
      Add(t, _) -> t
      Start(t) -> t
      Stop(t) -> t
    }
  }

  let ltime = occurred_at(left)
  let rtime = occurred_at(right)
  timestamp.compare(ltime, rtime)
}
