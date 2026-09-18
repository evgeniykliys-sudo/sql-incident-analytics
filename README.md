# sql-incident-analytics

SQL-аналитика по реальным логам инцидентов LLM-сервиса из [llm-api-monitoring-demo](https://github.com/evgeniykliys-sudo/llm-api-monitoring-demo). Отвечает на вопросы, которые реально задаёт дежурный инженер при разборе инцидента: где скачок ошибок, какой их тип, что с этим делать, сколько запросов "выжило" во время деградации сервиса.

## Запуск
```bash
docker-compose up -d
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python load_logs.py
```

Затем можно выполнить запросы из `queries.sql` через любой SQL-клиент (psql, DBeaver, DataGrip) или:
```bash
docker exec -it sql-incident-analytics-postgres-1 psql -U postgres -d incidents -f /dev/stdin < queries.sql
```

## Данные
`raw_logs.txt` — реальный (не синтетический) вывод `docker compose logs simulator -t` из llm-api-monitoring-demo: 378 строк, включая полный цикл одного инцидента.

## Что внутри
- `schema.sql` — 3 таблицы: `requests` (сырые события), `error_catalog` (справочник ошибок с severity и рекомендованным действием), `incidents` (зафиксированные окна инцидентов)
- `load_logs.py` — парсит логи, сшивает incident_started/resolved в пары, грузит в PostgreSQL
- `queries.sql` — 8 аналитических запросов с комментариями: агрегации, JOIN (включая range join по времени), window functions (moving average, RANK), подзапросы
