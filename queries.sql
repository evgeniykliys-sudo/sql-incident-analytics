-- ============================================================
-- 1. Общая статистика: сколько запросов, какой error rate
-- ============================================================
SELECT
    COUNT(*) AS total_requests,
    COUNT(*) FILTER (WHERE status = 'error') AS total_errors,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'error') / COUNT(*), 2) AS error_rate_pct
FROM requests;

-- ============================================================
-- 2. Ошибки по типу с расшифровкой из справочника (JOIN)
--    — то, что реально увидит дежурный: не просто код ошибки,
--    а severity и что с этим делать
-- ============================================================
SELECT
    r.error_type,
    COUNT(*) AS occurrences,
    ec.severity,
    ec.recommended_action
FROM requests r
JOIN error_catalog ec ON ec.error_type = r.error_type
WHERE r.status = 'error'
GROUP BY r.error_type, ec.severity, ec.recommended_action
ORDER BY occurrences DESC;

-- ============================================================
-- 3. Сравнение метрик "во время инцидента" vs "в норме"
--    — наглядно показывает эффект инцидента на error rate и латентность
-- ============================================================
SELECT
    incident_mode,
    COUNT(*) AS requests,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'error') / COUNT(*), 2) AS error_rate_pct,
    ROUND(AVG(duration_ms)) AS avg_duration_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)) AS p95_duration_ms
FROM requests
GROUP BY incident_mode
ORDER BY incident_mode;

-- ============================================================
-- 4. Запросы, попавшие в официально зафиксированное окно инцидента
--    (JOIN по диапазону времени, а не по флагу incident_mode —
--    так проверяем, что оба источника согласуются)
-- ============================================================
SELECT
    r.request_id,
    r.logged_at,
    r.status,
    r.duration_ms,
    i.id AS incident_id
FROM requests r
JOIN incidents i
    ON r.logged_at BETWEEN i.started_at AND COALESCE(i.resolved_at, now())
ORDER BY r.logged_at;

-- ============================================================
-- 5. Скользящее среднее длительности запроса (window function)
--    — помогает увидеть тренд на графике без внешнего инструмента
-- ============================================================
SELECT
    request_id,
    logged_at,
    duration_ms,
    ROUND(AVG(duration_ms) OVER (
        ORDER BY logged_at
        ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
    )) AS moving_avg_10
FROM requests
ORDER BY logged_at;

-- ============================================================
-- 6. Топ-5 самых медленных запросов — куда смотреть в первую очередь
-- ============================================================
SELECT request_id, logged_at, duration_ms, status, error_type
FROM requests
ORDER BY duration_ms DESC
LIMIT 5;

-- ============================================================
-- 7. Ранжирование типов ошибок по частоте (window function RANK)
-- ============================================================
SELECT
    error_type,
    COUNT(*) AS occurrences,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS rank
FROM requests
WHERE error_type IS NOT NULL
GROUP BY error_type;

-- ============================================================
-- 8. Аномалия: успешные запросы внутри окна инцидента —
--    сколько запросов "выжило" несмотря на деградацию сервиса
--    (подзапрос + агрегация)
-- ============================================================
SELECT
    (SELECT COUNT(*) FROM requests WHERE incident_mode = true) AS total_during_incident,
    (SELECT COUNT(*) FROM requests WHERE incident_mode = true AND status = 'success') AS succeeded_during_incident;
