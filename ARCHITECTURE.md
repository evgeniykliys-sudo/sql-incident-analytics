# Архитектура: sql-incident-analytics

## Цель (1 предложение)
SQL-аналитика по реальным логам инцидентов LLM-сервиса (источник данных — [llm-api-monitoring-demo](https://github.com/evgeniykliys-sudo/llm-api-monitoring-demo)): загрузка в PostgreSQL и аналитические запросы, отвечающие на реальные вопросы дежурного инженера при разборе инцидента.

## Модули
| Модуль | Файл | Описание |
|--------|------|----------|
| Схема БД | schema.sql | Таблицы requests, error_catalog (справочник severity/действий), incidents (окна инцидентов) |
| Загрузка логов | load_logs.py | Парсит `raw_logs.txt` (реальный вывод `docker compose logs -t`), сшивает события incident_started/resolved в окна, загружает всё в PostgreSQL |
| Аналитика | queries.sql | 8 запросов: агрегации, JOIN (в т.ч. по диапазону времени), window functions, подзапросы |

## Данные
`raw_logs.txt` — реальный, не синтетический лог из работающего llm-api-monitoring-demo (378 строк, включая один полный цикл инцидента: incident_started → incident_resolved).

## Стек
- PostgreSQL 16 (в Docker)
- psycopg2 — загрузка данных из Python
- Чистый SQL для аналитики (без ORM — специально, чтобы показать сам SQL, а не абстракцию поверх него)

## Схема
```
docker compose logs simulator -t  →  raw_logs.txt  →  load_logs.py  →  PostgreSQL
                                                                              ↓
                                                                        queries.sql
```

## Что демонстрируют запросы (queries.sql)
1. Общая статистика / error rate — базовая агрегация
2. Ошибки по типу + JOIN на справочник severity/действий — реальный сценарий "что делать дежурному"
3. Сравнение метрик в инциденте vs в норме — GROUP BY + FILTER + PERCENTILE_CONT
4. JOIN по диапазону времени (запросы внутри окна инцидента) — не тривиальный equi-join
5. Скользящее среднее — window function (ROWS BETWEEN ... PRECEDING)
6. Топ-5 самых медленных запросов
7. RANK() по частоте ошибок — window function
8. Подзапросы — аномалия "успешные запросы несмотря на инцидент"
