-- Notifications table for in-app notifications
-- Used with Supabase Realtime for push-like notifications

do $$ begin
    create type notification_type as enum ('report_recovered', 'report_verified', 'badge_earned', 'system');
exception
    when duplicate_object then null;
end $$;

create table if not exists public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  type notification_type not null,
  title text not null,
  body text,
  data jsonb, -- Additional data (e.g., report_id, badge_id)
  read boolean default false,
  created_at timestamptz default now()
);

-- Index for efficient queries
create index if not exists notifications_user_id_idx on public.notifications(user_id);
create index if not exists notifications_created_at_idx on public.notifications(created_at desc);
create index if not exists notifications_unread_idx on public.notifications(user_id) where read = false;

-- Enable RLS
alter table public.notifications enable row level security;

-- Users can only see their own notifications
drop policy if exists "Users can view own notifications." on public.notifications;
create policy "Users can view own notifications." on public.notifications
  for select using (auth.uid() = user_id);

-- Users can update (mark as read) their own notifications
drop policy if exists "Users can update own notifications." on public.notifications;
create policy "Users can update own notifications." on public.notifications
  for update using (auth.uid() = user_id);

-- System/triggers can insert notifications (using service role)
drop policy if exists "Service role can insert notifications." on public.notifications;
create policy "Service role can insert notifications." on public.notifications
  for insert with check (true);

-- Enable Realtime for this table
alter publication supabase_realtime add table public.notifications;

-- Trigger function to create notification when a report is recovered
create or replace function public.notify_report_recovered()
returns trigger as $$
declare
  report_owner_id uuid;
  report_address text;
begin
  -- Only trigger when status changes to 'resolved'
  if new.status = 'resolved' and (old.status is null or old.status != 'resolved') then
    -- Get the report owner
    select user_id, address into report_owner_id, report_address
    from public.reports
    where id = new.id;

    -- Don't notify if the user recovered their own report
    if report_owner_id is not null and report_owner_id != auth.uid() then
      insert into public.notifications (user_id, type, title, body, data)
      values (
        report_owner_id,
        'report_recovered',
        'Your report was recovered!',
        coalesce('The pollution at ' || report_address || ' has been cleaned up.', 'A pollution site you reported has been cleaned up.'),
        jsonb_build_object('report_id', new.id)
      );
    end if;
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_report_recovered on public.reports;
create trigger on_report_recovered
  after update on public.reports
  for each row execute procedure public.notify_report_recovered();
