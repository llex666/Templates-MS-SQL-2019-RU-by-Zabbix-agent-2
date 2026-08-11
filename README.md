# Zabbix-шаблон для мониторинга MS SQL Server 2019 (RU) через Zabbix agent 2

Шаблон для мониторинга **русской (RU)** версии Microsoft SQL Server 2019 через **Zabbix agent 2** с помощью PowerShell-скриптов и `UserParameter`.

За основу взята статья для английской версии MS SQL 2019: https://internet-lab.ru/zabbix_template_mssql_2019

> Шаблон разработан именно под русскоязычные счётчики производительности MS SQL. Если у вас английская версия MSSQL — используйте оригинальный шаблон по ссылке выше, либо адаптируйте счётчики под свою локаль.

## Возможности

Шаблон покрывает следующие группы метрик (см. приложения в самом шаблоне):

- **MS SQL Server** — версия, доступность, службы (`MS SQL Services`)
- **MS SQL CPU** — загрузка процессора
- **MS SQL Memory** — счётчики Buffer Manager
- **MS SQL Physical Disk** — дисковая подсистема
- **MS SQL DB** — автообнаружение баз данных, состояние, mirroring/AlwaysOn
- **MS SQL Jobs** — автообнаружение и мониторинг заданий SQL Server Agent (Database Maintenance)

## Структура репозитория

```
.
├── templates/
│   └── template_mssql_2019_ru_agent2.xml   # экспорт шаблона Zabbix (формат 5.0)
├── scripts/
│   ├── instances_info.ps1                  # обнаружение и статус служб MSSQL
│   ├── mssql_basename.ps1                  # автообнаружение баз данных
│   ├── mssql_jobs.ps1                      # автообнаружение и опрос заданий агента
│   └── mssql_version.ps1                   # версия MSSQL (использует Invoke-Sqlcmd)
├── zabbix_agent2.conf.d/
│   └── userparameter_mssql.conf            # UserParameter для agent 2
└── README.md
```

## Требования

- Microsoft SQL Server 2019 (русская локаль)
- Zabbix agent 2 на сервере с MSSQL (Windows)
- PowerShell (модуль `SqlServer` / `Invoke-Sqlcmd` для `mssql_version.ps1`)
- SQL-логин с правами на чтение нужных представлений `sys.*` и таблиц `msdb.dbo.sysjobs*`
- Zabbix сервер версии, совместимой с форматом экспорта шаблона (5.0+)

## Установка

1. **Скопируйте скрипты.**
   Папку `scripts` скопируйте в `C:\zabbix\scripts` на сервере с MSSQL.

2. **Скопируйте конфигурацию UserParameter.**
   Файл из `zabbix_agent2.conf.d\userparameter_mssql.conf` скопируйте в `C:\zabbix\zabbix_agent2.conf.d`.
   Подключите эту папку в конфигурационном файле агента (`Include=...`).
   Пути можно изменить на свои — тогда поправьте их и в `.conf`, и в самих `.ps1`.

3. **Настройте учётные данные для подключения к MSSQL.**
   В файлах `mssql_basename.ps1` и `mssql_jobs.ps1` пропишите пользователя и пароль:
   ```powershell
   $uid = "пользователь"
   $pwd = "пароль"
   ```
   Либо переключитесь на Integrated Security, раскомментировав соответствующую строку `$connectionString` и закомментировав вариант с `$uid`/`$pwd`.

   > ⚠️ **Безопасность.** Пароль хранится в открытом виде в `.ps1`-файле на диске. Используйте отдельную учётную запись MSSQL с минимально необходимыми правами (только чтение нужных объектов), ограничьте доступ к файлам скриптов на файловой системе и не используйте `sa` в проде.

4. **Разрешите выполнение UserParameter.**
   В конфиге Zabbix agent 2 включите:
   ```
   UnsafeUserParameters=1
   ```

5. **Перезапустите Zabbix agent 2.**

6. **Импортируйте шаблон.**
   В Zabbix импортируйте `templates/template_mssql_2019_ru_agent2.xml` и привяжите к хосту с MSSQL.

## Настройка через макросы

Все макросы можно переопределить на уровне хоста.

### Автообнаружение и хранение данных

| Макрос | Значение по умолчанию | Описание |
|---|---|---|
| `{$SQL_DB_DISCOVERY_PERIOD}` | 300 | Периодичность автообнаружения баз |
| `{$SQL_JOBS_DISCOVERY_PERIOD}` | 1h | Периодичность автообнаружения заданий (jobs) |
| `{$SQL_DB_DISCOVERY_REGEXP}` | `^(master\|model\|msdb\|ReportServer\|ReportServerTempDB\|tempdb)$` | Регулярное выражение со списком баз, которые не нужно обнаруживать |
| `{$SQL_HISTORY_PERIOD}` | 30d | Срок хранения истории |
| `{$SQL_HOT_REQUEST_PERIOD}` | — | Периодичность опроса: часто |
| `{$SQL_SHORT_REQUEST_PERIOD}` | — | Периодичность опроса: не очень часто |
| `{$SQL_MEDIUM_REQUEST_PERIOD}` | — | Периодичность опроса: средняя |
| `{$SQL_LONG_REQUEST_PERIOD}` | — | Периодичность опроса: очень редко |
| `{$SQL_TREND_PERIOD}` | 180d | Срок хранения трендов |
| `{$SQL_THROTTLING_HB_PERIOD}` | 6h | Троттлинг для списка инстансов, чтобы не хранить много лишнего в базе (можно увеличить) |

### Параметры сервера

| Макрос | Значение по умолчанию | Описание |
|---|---|---|
| `{$SQL_SERVICE_REQUEST_PERIOD}` | — | Периодичность опроса служб |
| `{$SQL_TCP_PORT}` | 1433 | Порт MSSQL, используется в триггере |

### Buffer Manager

| Макрос | Значение по умолчанию | Описание |
|---|---|---|
| `{$SQL_BUFFER_HIT_RATIO_HIGH}` | 2 | Buffer cache hit ratio (%), порог для триггера HIGH |
| `{$SQL_BUFFER_HIT_RATIO_WARNING}` | 4 | Buffer cache hit ratio (%), порог для триггера WARNING |
| `{$SQL_BUFFER_LAZY_WR_SEC_MAX}` | 2000 | Максимум Lazy writes/sec для триггера |
| `{$SQL_BUFFER_PAGE_R_SEC_MAX}` | 25000 | Максимум Page reads/sec для триггера |
| `{$SQL_BUFFER_PAGE_WR_SEC_MAX}` | 25000 | Максимум Page writes/sec для триггера |
| `{$SQL_BUFFER_STALL_SEC_MAX}` | 100 | Максимум Free list stalls/sec для триггера |

### Databases

| Макрос | Значение по умолчанию | Описание |
|---|---|---|
| `{$SQL_DB_LOG_FWT_MAX}` | 3000 | Максимальное время (мс) Log Flush Wait Time для триггера |
| `{$SQL_DB_LOG_FW_SEC_MAX}` | 3000 | Максимум Log Flush Waits/sec для триггера |

### Статистика (Locks / Access Methods)

| Макрос | Значение по умолчанию | Описание |
|---|---|---|
| `{$SQL_STAT_LOCKS_AWT_MAX}` | 20000 | Максимальное среднее время ожидания блокировок (Locks: Average Wait Time, Total) |
| `{$SQL_STAT_LOCKS_REQUESTS_SEC_MAX}` | 900000 | Максимум Lock Requests/sec (Total) для триггера |
| `{$SQL_STAT_LOCKS_TIMEOUTS_SEC_MAX}` | 3000 | Максимум Lock Timeouts/sec (Total) для триггера |
| `{$SQL_STAT_WORK_FILES_MAX}` | 3000 | Максимум Work files created/sec для триггера |
| `{$SQL_STAT_WORK_TABLES_MAX}` | 1000 | Максимум Work tables created/sec для триггера |

