Шаблон для мониторинга MS SQL Server 2019 by Zabbix agent 2


Установка

Папку со скриптами PowerShell копируем в C:\zabbix\scripts. Папку с файлом пользовательских переменных копируем в C:\zabbix\zabbix_agent2.conf.d. 
Папку подключаем в конфигурационном файле агента Zabbix. Вы можете использовать и другие пути, но тогда вам нужно будет отредактировать файл конфигурации.

Модифицируем файлы mssql_basename.ps1 и mssql_jobs.ps1. Прописываем пользователя и пароль для доступа к базе данных:
&uid = "пользователь"
&pwd = "пароль"

Разрешаем запуск неподписанных PowerShell скриптов на сервере.
В конфиге агента включите параметр  UnsafeUserParameters=1.
Перезапускаем zabbix agent 2. Добавляем шаблон хосту с БД.




Модифицируем макросы для тонкой настройки. Макросы можно переопределить для каждого хоста.

Параметры автообнаружения :

{$SQL_DB_DISCOVERY_PERIOD} — 300. Периодичность автообнаружения баз.
{$SQL_JOBS_DISCOVERY_PERIOD} — 1h. Периодичность автообнаружения джобов.
{$SQL_DB_DISCOVERY_REGEXP}. Регулярное выражение со списком баз, которые не нужно обнаруживать.
^(master|model|msdb|ReportServer|ReportServerTempDB|tempdb)$
{$SQL_HISTORY_PERIOD} — 30d. Срок хранения истории.
{$SQL_HOT_REQUEST_PERIOD} — Периодичность опроса. Часто.
{$SQL_SHORT_REQUEST_PERIOD} — Периодичность опроса. Не очень часто.
{$SQL_MEDIUM_REQUEST_PERIOD} — Периодичность опроса. Средняя.
{$SQL_LONG_REQUEST_PERIOD} — Периодичность опроса. Очень редко.
{$SQL_TREND_PERIOD} — 180d. Срок хранения трендов.
{$SQL_THROTTLING_HB_PERIOD} — 6h. Троттлинг для списка инстансов, чтобы не хранить много лишнего в базе. Можно увеличить.
Параметры сервера:

{$SQL_SERVICE_REQUEST_PERIOD} — Периодичность опроса служб.
{$SQL_TCP_PORT} — 1433. Порт MSSQL, для триггера.
Параметры Buffer Manager:

{$SQL_BUFFER_HIT_RATIO_HIGH} — 2. Процент Buffer Manager: Buffer cache hit ratio для триггера HIGH.
{$SQL_BUFFER_HIT_RATIO_WARNING} — 4. Процент Buffer Manager: Buffer cache hit ratio для триггера WARNING.
{$SQL_BUFFER_LAZY_WR_SEC_MAX} — 2000. Максимальное значение Buffer Manager: Lazy writes/sec для триггера.
{$SQL_BUFFER_PAGE_R_SEC_MAX} — 25000. Максимальное значение Buffer Manager: Page reads/sec для триггера.
{$SQL_BUFFER_PAGE_WR_SEC_MAX} — 25000. Максимальное значение Buffer Manager: Page writes/sec для триггера.
{$SQL_BUFFER_STALL_SEC_MAX} — 100. Максимальное значение Buffer Manager: Free list stalls/sec для триггера.
Параметры Databases:

{$SQL_DB_LOG_FWT_MAX} — 3000. Максимальное время (мс) SQLServer:Databases: Log Flush Wait Time для триггера.
{$SQL_DB_LOG_FW_SEC_MAX} — 3000. Максимальное количество SQLServer:Databases: Log Flush Waits/sec для триггера.
Параметры статистики:

{$SQL_STAT_LOCKS_AWT_MAX} — 20000. Максимальное среднее время ожидания блокировок Locks: Average Wait Time (Total) для триггера.
{$SQL_STAT_LOCKS_REQUESTS_SEC_MAX} — 900000. Максимальное количество блокировок в секунду Locks: Lock Requests/sec (Total) для триггера.
{$SQL_STAT_LOCKS_TIMEOUTS_SEC_MAX} — 3000. Максимальный таймаут блокировок Locks: Lock Timeouts/sec (Total) для триггера.
{$SQL_STAT_WORK_FILES_MAX} — 3000. Максимальное количество новых рабочих файлов в секунду Access Methods: Work files created/sec для триггера.
{$SQL_STAT_WORK_TABLES_MAX} — 1000. Максимальное количество новых рабочих таблиц в секунду Access Methods: Work tables created/sec для триггера.



