CREATE TABLE IF NOT EXISTS nginx_requests (
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
    raw_log_hash text not null,
    created_at timestamptz not null default now(),

    CONSTRAINT nginx_requests_raw_log_hash_unique
        UNIQUE (raw_log_hash)
);