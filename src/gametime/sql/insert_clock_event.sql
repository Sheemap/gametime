insert into public.clock_events (timestamp, clock_id, event_type, remaining_time)
values (CURRENT_TIMESTAMP at time zone 'UTC', $1, $2, $3)


