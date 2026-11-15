-- StatePulse Supabase Cloud Database Schema

-- 1. Таблица чек-инов (срезов состояния)
CREATE TABLE IF NOT EXISTS public.check_ins (
    id UUID PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    body_energy INT NOT NULL DEFAULT 7,
    mental_resource INT NOT NULL DEFAULT 7,
    focus INT NOT NULL DEFAULT 7,
    tags TEXT[] NOT NULL DEFAULT '{}',
    note TEXT NOT NULL DEFAULT '',
    screen_time_seconds INT NOT NULL DEFAULT 0,
    metric_scores JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_check_ins_timestamp ON public.check_ins(timestamp DESC);

-- 2. Таблица пользовательских тегов
CREATE TABLE IF NOT EXISTS public.custom_tags (
    name TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Таблица шкал (метрик)
CREATE TABLE IF NOT EXISTS public.custom_metrics (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    subtitle TEXT NOT NULL DEFAULT '',
    icon TEXT NOT NULL DEFAULT 'target',
    color_hex BIGINT NOT NULL DEFAULT 4294967295,
    order_index INT NOT NULL DEFAULT 0,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Политики безопасности (Row Level Security для anon и authenticated)
ALTER TABLE public.check_ins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon all on check_ins" ON public.check_ins;
CREATE POLICY "Allow anon all on check_ins" ON public.check_ins FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.custom_tags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon all on custom_tags" ON public.custom_tags;
CREATE POLICY "Allow anon all on custom_tags" ON public.custom_tags FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.custom_metrics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow anon all on custom_metrics" ON public.custom_metrics;
CREATE POLICY "Allow anon all on custom_metrics" ON public.custom_metrics FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
