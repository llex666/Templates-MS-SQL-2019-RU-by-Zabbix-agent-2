#функция для приведения к формату который понимает zabbix / the function is to bring to the format understands zabbix
function convertto-encoding ([string]$from, [string]$to){
    begin{
        $encfrom = [system.text.encoding]::getencoding($from)
        $encto = [system.text.encoding]::getencoding($to)
    }
    process{
        $bytes = $encto.getbytes($_)
        $bytes = [system.text.encoding]::convert($encfrom, $encto, $bytes)
        $encto.getstring($bytes)
    }
}

#Задаем переменные для подключение к MSSQL. $uid и $pwd нужны для проверки подлинности windows / We define the variables for connecting to MS SQL. $uid и $pwd need to authenticate windows
$SQLServer = $(hostname.exe)
$uid = "sa"
$pwd = "password"

#Создаем подключение к MSSQL / Create a connection to MSSQL

#Если проверка подлинности windows / If windows authentication
$connectionString = "Server = $SQLServer; User ID = $uid; Password = $pwd;"

#Если Интегрированная проверка подлинности / If integrated authentication
#$connectionString = "Server = $SQLServer; Integrated Security = True;"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()

#Создаем запрос непосредственно к MSSQL / Create a request directly to MSSQL
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand  

if ([string]::IsNullOrEmpty($args[0]) -and [string]::IsNullOrEmpty($args[1])) {
  $SqlCmd.CommandText = "
  SELECT [sSVR].[name] + '.' +[sJOB].[name] AS [JobName]
  FROM [msdb].[dbo].[sysjobs] AS [sJOB] WITH (NOLOCK)
  INNER JOIN [msdb].[sys].[servers] AS [sSVR] WITH (NOLOCK)
  ON [sJOB].[originating_server_id] = [sSVR].[server_id]
  INNER JOIN [msdb].[dbo].[syscategories] AS [sCAT] WITH (NOLOCK)
  ON [sJOB].[category_id] = [sCAT].[category_id] AND [sCAT].[name] = N'Database Maintenance'
  LEFT JOIN (
      SELECT ss1.* FROM [msdb].[dbo].[sysjobsteps] AS ss1 WITH (NOLOCK)
      INNER JOIN (
        SELECT DISTINCT tj1.[job_id], (
          SELECT TOP 1 tj2.[step_id]
          FROM [msdb].[dbo].[sysjobsteps] AS tj2 WITH (NOLOCK)
          WHERE tj2.[job_id] = tj1.[job_id]
          ORDER BY tj2.last_run_date DESC, tj2.last_run_Time DESC, tj2.step_id DESC
        ) AS step_id
        FROM [msdb].[dbo].[sysjobsteps] AS tj1 WITH (NOLOCK)
      ) ss2
      ON ss1.[job_id] = ss2.[job_id] AND ss1.[step_id] = ss2.[step_id]
  ) AS [sJSTP]
  ON [sJOB].[job_id] = [sJSTP].[job_id]   
  LEFT JOIN (
      SELECT (
          SELECT TOP 1 schedule_id
          FROM [msdb].[dbo].[sysjobschedules] AS tts1 WITH (NOLOCK)
          WHERE tts1.job_id = tts2.job_id AND tts1.next_run_date = MIN(tts2.next_run_date)
          ORDER BY tts1.next_run_date DESC, tts1.next_run_time DESC
      ) AS schedule_id,
      job_id,
      MIN(next_run_date) AS next_run_date,
      (
          SELECT TOP 1 next_run_time
          FROM [msdb].[dbo].[sysjobschedules] AS tts3 WITH (NOLOCK)
          WHERE tts3.job_id = tts2.job_id AND tts3.next_run_date = MIN(tts2.next_run_date)
          ORDER BY tts3.next_run_date DESC, tts3.next_run_time DESC
      ) AS next_run_time
      FROM [msdb].[dbo].[sysjobschedules] AS tts2
      WHERE next_run_date <> 0
      GROUP BY job_id
  ) AS [sJOBSCH]
  ON [sJOB].[job_id] = [sJOBSCH].[job_id]
  LEFT JOIN [msdb].[dbo].[sysschedules] AS [sSCH] WITH (NOLOCK)
  ON [sJOBSCH].[schedule_id] = [sSCH].[schedule_id]
  LEFT JOIN (
      SELECT job_id, instance_id = MAX(instance_id), MAX(run_duration) AS run_duration
      FROM [msdb].[dbo].sysjobhistory WITH (NOLOCK)
      GROUP BY job_id
  ) AS l
  ON sJOB.job_id = l.job_id
  LEFT JOIN [msdb].[dbo].sysjobhistory AS h WITH (NOLOCK)
  ON h.job_id = l.job_id AND h.instance_id = l.instance_id
  ORDER BY [JobName]
  "
} else {
  $SqlCmd.CommandText = "
  SELECT
    CASE UPPER(@JobValue)
      WHEN 'SERVERNAME' THEN [sSVR].[name]
      WHEN 'CREATED' THEN CONVERT(VARCHAR, [sJOB].[date_created], 121)
      WHEN 'MODIFIED' THEN ISNULL(CONVERT(VARCHAR, [sJOB].[date_modified], 121), '')
      WHEN 'IS_ENABLED' THEN CASE [sJOB].[enabled] WHEN 1 THEN '1' ELSE '0' END
      WHEN 'IS_SCHEDULED' THEN CASE WHEN [sSCH].[schedule_uid] IS NULL THEN '0' ELSE '1' END
      WHEN 'SCHEDULE_TYPE' THEN ISNULL(LTRIM(RTRIM(STR([freq_type]))), '0')
      WHEN 'SCHEDULE_INTERVAL' THEN ISNULL(LTRIM(RTRIM(STR([freq_interval]))), '0')
      WHEN 'SCHEDULE_RELATIVE_INTERVAL' THEN ISNULL(LTRIM(RTRIM(STR([freq_relative_interval]))), '')
      WHEN 'SCHEDULE_SUBDAY_TYPE' THEN ISNULL(LTRIM(RTRIM(STR([freq_subday_type]))), '0')
      WHEN 'SCHEDULE_SUBDAY_INTERVAL' THEN ISNULL(LTRIM(RTRIM(STR([freq_subday_interval]))), '0')
      WHEN 'SCHEDULE_RECURRENCE_FACTOR' THEN ISNULL(LTRIM(RTRIM(STR([freq_recurrence_factor]))), '0')
      WHEN 'LAST_RUN' THEN ISNULL(CONVERT(VARCHAR, CONVERT(DATETIME, RTRIM(run_date) + ' ' + STUFF(STUFF(REPLACE(STR(RTRIM(h.run_time),6,0),' ','0'),3,0,':'),6,0,':')), 121),'')
      WHEN 'LAST_RUN_TIMESTAMP' THEN ISNULL(CONVERT(VARCHAR, DATEDIFF(SECOND, {d '1970-01-01'}, CONVERT(DATETIME, RTRIM(run_date) + ' ' + STUFF(STUFF(REPLACE(STR(RTRIM(h.run_time),6,0),' ','0'),3,0,':'),6,0,':')))), '0')
      WHEN 'LAST_RUN_STATUS' THEN ISNULL(LTRIM(RTRIM(STR([sJSTP].Last_run_outcome))), '')
      WHEN 'LAST_RUN_DURATION' THEN ISNULL(STUFF(STUFF(REPLACE(STR([sJSTP].last_run_duration,7,0),' ','0'),4,0,':'),7,0,':'), '')
      WHEN 'NEXT_RUN' THEN ISNULL(CONVERT(VARCHAR,  CONVERT(DATETIME, RTRIM(NULLIF([sJOBSCH].next_run_date, 0)) +' '+ STUFF(STUFF(REPLACE(STR(RTRIM([sJOBSCH].next_run_time),6,0),' ','0'),3,0,':'),6,0,':')), 121), '')
      WHEN 'MESSAGE' THEN ISNULL(h.Message, '')
      ELSE [sSVR].[name] + '.' +[sJOB].[name]
    END AS [JobValue]
  FROM [msdb].[dbo].[sysjobs] AS [sJOB] WITH (NOLOCK)
  INNER JOIN [msdb].[sys].[servers] AS [sSVR] WITH (NOLOCK)
  ON [sJOB].[originating_server_id] = [sSVR].[server_id]
  INNER JOIN [msdb].[dbo].[syscategories] AS [sCAT] WITH (NOLOCK)
  ON [sJOB].[category_id] = [sCAT].[category_id] AND [sCAT].[name] = N'Database Maintenance'
  LEFT JOIN (
    SELECT ss1.* FROM [msdb].[dbo].[sysjobsteps] AS ss1 WITH (NOLOCK)
    INNER JOIN (
      SELECT DISTINCT tj1.[job_id], (
        SELECT TOP 1 tj2.[step_id]
        FROM [msdb].[dbo].[sysjobsteps] AS tj2 WITH (NOLOCK)
        WHERE tj2.[job_id] = tj1.[job_id]
        ORDER BY tj2.last_run_date DESC, tj2.last_run_Time DESC, tj2.step_id DESC
      ) AS step_id
      FROM [msdb].[dbo].[sysjobsteps] AS tj1 WITH (NOLOCK)
    ) ss2
    ON ss1.[job_id] = ss2.[job_id] AND ss1.[step_id] = ss2.[step_id]
  ) AS [sJSTP]
  ON [sJOB].[job_id] = [sJSTP].[job_id]
  LEFT JOIN (
    SELECT (
      SELECT TOP 1 schedule_id
      FROM [msdb].[dbo].[sysjobschedules] AS tts1 WITH (NOLOCK)
      WHERE tts1.job_id = tts2.job_id AND tts1.next_run_date = MIN(tts2.next_run_date)
      ORDER BY tts1.next_run_date DESC, tts1.next_run_time DESC
    ) AS schedule_id,
    job_id,
    MIN(next_run_date) AS next_run_date,
    (
      SELECT TOP 1 next_run_time
      FROM [msdb].[dbo].[sysjobschedules] AS tts3 WITH (NOLOCK)
      WHERE tts3.job_id = tts2.job_id AND tts3.next_run_date = MIN(tts2.next_run_date)
      ORDER BY tts3.next_run_date DESC, tts3.next_run_time DESC
    ) AS next_run_time
    FROM [msdb].[dbo].[sysjobschedules] AS tts2
    WHERE next_run_date <> 0
    GROUP BY job_id
  ) AS [sJOBSCH]
  ON [sJOB].[job_id] = [sJOBSCH].[job_id]
  LEFT JOIN [msdb].[dbo].[sysschedules] AS [sSCH] WITH (NOLOCK)
  ON [sJOBSCH].[schedule_id] = [sSCH].[schedule_id]
  LEFT JOIN (
    SELECT job_id, instance_id = MAX(instance_id), MAX(run_duration) AS run_duration
    FROM [msdb].[dbo].sysjobhistory WITH (NOLOCK)
    GROUP BY job_id
  ) AS l
  ON sJOB.job_id = l.job_id
  LEFT JOIN [msdb].[dbo].sysjobhistory AS h WITH (NOLOCK)
  ON h.job_id = l.job_id AND h.instance_id = l.instance_id
  WHERE [sSVR].[name] + '.' +[sJOB].[name] = @JobName
  "
  $SqlCmd.Parameters.AddWithValue("@JobName", $args[0].ToString()) | Out-Null;
  $SqlCmd.Parameters.AddWithValue("@JobValue", $args[1].ToString()) | Out-Null;
}

$SqlCmd.Connection = $Connection
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd
$DataSet = New-Object System.Data.DataSet
$SqlAdapter.Fill($DataSet) > $null
$Connection.Close()

# Получили список джобов. Записываем в переменную. / We get a list of jobs. Write to the variable.
$jobs = $DataSet.Tables[0]

# Парсим и передаем список джобов в zabbix. В последней строке нужно вывести имя джоба без запятой в конце. / Parse and pass a list of jobs in zabbix. In the last line need to display the job name without a comma at the end.
$idx = 1

if ([string]::IsNullOrEmpty($args[0])) {
  write-host "{ `"data`" : [ "
  foreach ($name in $jobs)
  {
    $line= "{`"{#JOBNAME}`" : `"" + $name.JobName + "`"}"
    if ($idx -lt $jobs.Rows.Count) {$line= $line + ","}
    $line= $line | convertto-encoding "cp866" "utf-8"
    write-host $line
    $idx++;
  }
  write-host " ]}"
} else {
  foreach ($name in $jobs)
  {
    $line = $name.JobValue | convertto-encoding "cp866" "utf-8"
    write-host $line
    $idx++;
  }
}
