-- Create a function to fetch lightweight heatmap data
-- Returns only location and weight for active reports (verified/resolved)
create or replace function get_heatmap_points()
returns table (
  id uuid,
  lat double precision,
  lng double precision,
  weight double precision -- derived from severity
)
language plpgsql
security definer
as $$
begin
  return query
  select
    r.id,
    st_y(r.location::geometry) as lat,
    st_x(r.location::geometry) as lng,
    case
       -- Heavier weight for higher severity
       when r.severity = 3 then 1.0
       when r.severity = 2 then 0.6
       else 0.3
    end as weight
  from reports r
  where r.status = 'verified' or r.status = 'resolved';
end;
$$;
