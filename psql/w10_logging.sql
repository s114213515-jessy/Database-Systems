-- Run against fastapi_dev as a PostgreSQL administrator.
-- This script is safe to run more than once and does not delete existing data.

CREATE TABLE IF NOT EXISTS public.api_sessions (
    id uuid PRIMARY KEY,
    member_id bigint,
    ip inet,
    started_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.api_logs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id uuid REFERENCES public.api_sessions(id) ON DELETE SET NULL,
    request_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    level varchar(10) NOT NULL,
    method varchar(10) NOT NULL,
    path text NOT NULL,
    status_code integer NOT NULL,
    duration_ms double precision NOT NULL CHECK (duration_ms >= 0),
    error_code varchar(100),
    message text,
    details jsonb
);

CREATE INDEX IF NOT EXISTS idx_api_logs_created_at
    ON public.api_logs (created_at);

CREATE INDEX IF NOT EXISTS idx_api_logs_session_created_at
    ON public.api_logs (session_id, created_at);

CREATE INDEX IF NOT EXISTS idx_api_logs_request_id
    ON public.api_logs (request_id);

DO $grant_w10_logging$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dev_user') THEN
        EXECUTE 'GRANT SELECT, INSERT, UPDATE ON public.api_sessions TO dev_user';
        EXECUTE 'GRANT INSERT ON public.api_logs TO dev_user';
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE public.api_logs_id_seq TO dev_user';
    ELSE
        RAISE NOTICE 'Role dev_user does not exist; create it and re-run the grants';
    END IF;
END;
$grant_w10_logging$;
