-- Заявки/запросы к симулированному LLM API (источник: llm-api-monitoring-demo)
CREATE TABLE IF NOT EXISTS requests (
    id SERIAL PRIMARY KEY,
    request_id VARCHAR(16) NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(10) NOT NULL,
    duration_ms INTEGER NOT NULL,
    error_type VARCHAR(20),
    incident_mode BOOLEAN NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_requests_logged_at ON requests (logged_at);
CREATE INDEX IF NOT EXISTS idx_requests_error_type ON requests (error_type);

-- Справочник типов ошибок — severity и рекомендованное действие для дежурного
CREATE TABLE IF NOT EXISTS error_catalog (
    error_type VARCHAR(20) PRIMARY KEY,
    severity VARCHAR(10) NOT NULL,
    description TEXT NOT NULL,
    recommended_action TEXT NOT NULL
);

INSERT INTO error_catalog (error_type, severity, description, recommended_action) VALUES
    ('rate_limit', 'medium', 'Превышен лимит запросов (429)', 'Проверить заголовок Retry-After; при регулярности — заявка на увеличение лимита'),
    ('timeout', 'high', 'Таймаут ответа от модели', 'Проверить нагрузку на backend; эскалировать, если ошибка массовая'),
    ('server_error', 'critical', 'Внутренняя ошибка сервиса (5xx)', 'Немедленная эскалация дежурному инженеру AI Platform')
ON CONFLICT (error_type) DO NOTHING;

-- Зафиксированные окна инцидентов (начало/конец) — из событий incident_started / incident_resolved
CREATE TABLE IF NOT EXISTS incidents (
    id SERIAL PRIMARY KEY,
    started_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ
);
