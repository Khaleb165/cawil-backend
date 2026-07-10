-- ============================================
-- Schema 1: users (JWT auth — replaces Firebase)
-- ============================================
do $$ begin create type user_role as enum ('user', 'admin'); exception when duplicate_object then null; end $$;

create table if not exists users (
    id            serial primary key,
    uid           varchar,
    email         varchar unique not null check(length(email) < 256),
    password_hash text not null,
    username      varchar unique not null check(length(username) > 0 and length(username) <= 30),
    avatar_url    varchar default '',
    role          user_role default 'user',
    created_at    timestamptz default now(),
    updated_at    timestamptz default now()
);

alter table users add column if not exists uid varchar;
create unique index if not exists users_uid_unique on users(uid) where uid is not null;

-- ============================================
-- Schema 2: buses (fleet) — 8 rows × 4 cols = 32 seats fixed layout
-- ============================================
do $$ begin create type bus_route_type as enum ('long-distance', 'local'); exception when duplicate_object then null; end $$;
do $$ begin create type vehicle_status as enum ('active', 'inactive'); exception when duplicate_object then null; end $$;

create table if not exists buses (
    id             serial primary key,
    bus_number     varchar unique not null check(length(bus_number) > 0 and length(bus_number) <= 20),
    plate_number   varchar,
    total_seats    int check(total_seats between 18 and 64),
    route_type     bus_route_type default 'long-distance',
    status         vehicle_status default 'active',
    created_at     timestamptz default now()
);

-- ============================================
-- Schema 3: routes (origin → destination corridors)
-- ============================================
do $$ begin create type routestatus as enum ('active', 'inactive'); exception when duplicate_object then null; end $$;

create table if not exists routes (
    id             serial primary key,
    origin         varchar not null check(length(origin) > 0 and length(origin) <= 80),
    destination    varchar not null check(length(destination) > 0 and length(destination) <= 80),
    duration_hours decimal check(duration_hours > 0 and duration_hours < 24),
    base_price     decimal(10,2) check(base_price >= 0),
    status         routestatus default 'active',
    created_at     timestamptz default now(),
    updated_at     timestamptz default now()
);

-- ============================================
-- Schema 4: schedules — the CORE table (connects buses to routes)
-- Each schedule has its own per-bus price (not route base_price)
-- ============================================
do $$ begin create type schedule_status as enum ('active', 'inactive', 'departed'); exception when duplicate_object then null; end $$;

create table if not exists schedules (
    id                   serial primary key,
    bus_id               int not null references buses(id) on delete cascade,
    route_id             int not null references routes(id) on delete cascade,
    origin               varchar not null check(length(origin) > 0 and length(origin) <= 80),
    destination          varchar not null check(length(destination) > 0 and length(destination) <= 80),
    departure_time       timestamptz not null,
    arrival_time         timestamptz,
    report_time          timestamptz,
    price                decimal(10,2) check(price >= 0),
    seats_remaining      int check(seats_remaining between 0 and 64),
    status               schedule_status default 'active',
    created_at           timestamptz default now()
);

alter table schedules add column if not exists report_time timestamptz;

do $$
declare
    report_time_is_generated text;
begin
    select is_generated
    into report_time_is_generated
    from information_schema.columns
    where table_schema = current_schema()
      and table_name = 'schedules'
      and column_name = 'report_time';

    if report_time_is_generated is not null and report_time_is_generated <> 'NEVER' then
        alter table schedules drop column report_time;
        alter table schedules add column report_time timestamptz;
    end if;

    if exists (
        select 1
        from information_schema.columns
        where table_schema = current_schema()
          and table_name = 'schedules'
          and column_name = 'report_time'
          and column_default is not null
    ) then
        alter table schedules alter column report_time drop default;
    end if;
end $$;

create or replace function set_schedule_report_time()
returns trigger as $$
begin
    new.report_time := new.departure_time - interval '30 minutes';
    return new;
end;
$$ language plpgsql;

do $$
begin
    update schedules
    set report_time = departure_time - interval '30 minutes'
    where report_time is null;

    if not exists (
        select 1
        from pg_trigger
        where tgname = 'set_schedule_report_time_trigger'
          and tgrelid = 'schedules'::regclass
    ) then
        create trigger set_schedule_report_time_trigger
        before insert or update of departure_time on schedules
        for each row
        execute function set_schedule_report_time();
    end if;
end $$;

-- ============================================
-- Schema 5: bookings — seat reservations
-- ============================================
do $$ begin create type booking_status as enum ('confirmed', 'cancelled', 'no_show'); exception when duplicate_object then null; end $$;
do $$ begin create type paymentstatus as enum ('pending', 'completed', 'refunded'); exception when duplicate_object then null; end $$;

create table if not exists bookings (
    id                serial primary key,
    user_id           int not null references users(id) on delete cascade,
    schedule_id       int not null references schedules(id) on delete cascade,
    seat_number       varchar not null check(length(seat_number) > 0 and length(seat_number) <= 4),
    passenger_name    varchar not null check(length(passenger_name) > 0 and length(passenger_name) <= 100),
    phone             varchar not null check(length(phone) > 0 and length(phone) <= 20),
    total_price       decimal(10,2) check(total_price >= 0),
    booking_ref       varchar unique not null check(length(booking_ref) > 0 and length(booking_ref) <= 20),
    qr_data           bytea not null default '\x', -- PDF blob stored here
    status            booking_status default 'confirmed',
    payment_status    paymentstatus default 'pending',
    created_at        timestamptz default now()
);

-- ============================================
-- Schema 6: refresh_tokens (single-use JWT refresh)
-- ============================================
create table if not exists refresh_tokens (
    id           serial primary key,
    user_id      int not null references users(id) on delete cascade,
    jti          varchar unique not null check(length(jti) > 0 and length(jti) <= 64),
    expires_at   timestamptz not null,
    revoked_at   timestamptz default null, -- set to now() when token is used for refresh
    created_at   timestamptz default now()
);

-- ============================================
-- Schema 7: admin_logs (audit trail)
-- ============================================
create table if not exists admin_logs (
    id           serial primary key,
    admin_id     int not null references users(id) on delete cascade,
    action       varchar not null check(length(action) > 0 and length(action) <= 60),
    target_type  varchar not null check(target_type in ('schedule', 'user', 'bus', 'route')),
    target_id    int, -- references the relevant table based on target_type
    timestamp    timestamptz default now()
);
