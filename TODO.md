# TODO: sql-incident-analytics

- [x] Поднять PostgreSQL через docker-compose
- [x] Написать load_logs.py — парсинг raw_logs.txt, загрузка в БД
- [x] Прогнать load_logs.py на реальных логах — 376 запросов, 1 инцидент
- [x] Прогнать все запросы из queries.sql — все 8 дали осмысленные результаты (error rate во время инцидента 60% против 3.5% в норме, p95 латентность 5856мс против 852мс)
- [x] Залить на GitHub, добавить в резюме и FREELANCE.md
