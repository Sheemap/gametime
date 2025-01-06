-- Given a clock ID, get all the clocks in the same room with their current states
select
	c.id,
    c.room_id,
	c.label,
    c.position,
	c.increment,
	c.initial_value,
	coalesce (latest_state.event_type, 'STOP') as state,
	coalesce (latest_event.remaining_time, c.initial_value) as remaining_time,
    -- Updated at in milliseconds
    (extract(epoch from coalesce (latest_event.timestamp, CURRENT_TIMESTAMP at time zone 'UTC')) * 1000) as updated_at
from
	public.clocks c
cross join (
	select
		r.id
	from
		public.rooms r
	inner join
		public.clocks c on c.room_id = r.id and c.id = $1
) as r
left join (
	select
		ce.clock_id,
		ce.event_type
	from
		public.clock_events ce
	join public.clocks c on
		ce.clock_id = c.id
		and ce.event_type in ('START', 'STOP')
	order by
		ce.timestamp desc
	limit 1
   ) latest_state on
	c.id = latest_state.clock_id
left join (
	select
		ce.timestamp,
		ce.clock_id,
		ce.event_type,
		ce.remaining_time
	from
		public.clock_events ce
	join public.clocks c on
		ce.clock_id = c.id
	order by
		ce.timestamp desc
	limit 1
   ) latest_event on
	c.id = latest_event.clock_id
where
   c.room_id = r.id
