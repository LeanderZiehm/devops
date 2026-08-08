create table if not exists nginx_requests (
    id bigint generated always as identity primary key,
    hostname text,
    request_time timestamptz not null,
    ip inet,
    method text,
    path text,
    protocol text,
    status smallint,
    response_bytes bigint,
    referer text,
    user_agent text,
    source_file text,
    raw_log text not null,
    created_at timestamptz not null default now()
);

create unique index if not exists nginx_requests_dedup_idx
on nginx_requests (request_time, ip, raw_log);