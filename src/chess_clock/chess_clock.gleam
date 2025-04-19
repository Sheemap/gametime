import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/time/duration
import gleam/time/timestamp

// A Clock is really just a list of ClockEvents which can be aggregated together to determine the ClockState
pub type Clock =
  List(ClockEvent)

pub type ClockState {
  ClockState(
    remaining_duration: duration.Duration,
    active_since: option.Option(timestamp.Timestamp),
  )
}

pub type ClockEvent {
  START(timestamp.Timestamp)
  STOP(timestamp.Timestamp)
  ADD(timestamp.Timestamp, duration.Duration)
}

// Start the clock
// Prepends a Start clock event
// If the clock is already running, this function is a noop
pub fn start_clock(clock: Clock) -> Clock {
  case check_clock(clock).active_since {
    None -> [START(timestamp.system_time()), ..clock]
    Some(_) -> clock
  }
}

// Stop the clock
// Prepends a Stop clock event
// If the clock is already stopped, this function is a noop
pub fn stop_clock(clock) {
  case check_clock(clock).active_since {
    None -> clock
    Some(_) -> [STOP(timestamp.system_time()), ..clock]
  }
}

// Adds time to the clock
// To subtract time, provide a negative duration
pub fn add_time(clock, duration: duration.Duration) {
  [ADD(timestamp.system_time(), duration), ..clock]
}

// Processes the clock events to get the current ClockState
pub fn check_clock(events: Clock) {
  let base_state = ClockState(duration.seconds(0), option.None)
  get_clock_state(base_state, list.reverse(events))
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
    [event, ..events_remainder] ->
      case event {
        START(time) -> {
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
        STOP(time) ->
          case state.active_since {
            None -> {
              echo "hia"
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
        ADD(_, dur) ->
          dur
          |> duration.add(state.remaining_duration)
          |> ClockState(state.active_since)
          |> get_clock_state(events_remainder)
      }
  }
}
