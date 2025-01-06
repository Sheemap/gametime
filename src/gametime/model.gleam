import birl.{type Time}
import birl/duration.{type Duration}
import gametime/sql
import gleam/json.{type Json}
import gleam/option.{type Option}

pub type Clock {
  Clock(
    id: String,
    label: String,
    position: Int,
    increment: Duration,
    initial_value: Duration,
    current_value: Duration,
  )
}

pub type Room {
  Room(id: String, clocks: List(Clock), active_clock: Option(String))
}

pub type ClockEvent {
  ClockEvent(
    clock_id: String,
    event_type: sql.ClockEventType,
    remaining_time: Duration,
    details: Option(Json),
  )
}

pub type FlatClock {
  FlatClock(
    id: String,
    room_id: String,
    label: String,
    position: Int,
    increment: Duration,
    initial_value: Duration,
    current_value: Duration,
    state: sql.ClockEventType,
    updated_at: Time,
  )
}

pub fn to_clock(flat_clock: FlatClock) {
    Clock(
    id:flat_clock.id,
    label:flat_clock.label,
    position:flat_clock.position,
    increment:flat_clock.increment,
    initial_value:flat_clock.initial_value,
    current_value:flat_clock.current_value,

    )

}
