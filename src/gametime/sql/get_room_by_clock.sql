-- Gets a room with a clock ID
select
  r.id, array_agg(c.id) as clock_ids
from
  rooms r
  join clocks c on c.room_id = r.id
where
  c.id = $1
group by
  r.id

