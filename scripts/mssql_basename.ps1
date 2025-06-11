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
$SqlCmd.CommandText = "
SELECT 
  ISNULL(d.name, 'NULL') AS name, 
  ISNULL(d.recovery_model_desc, 'NULL') AS recovery_model_desc, 
  ISNULL(d.state_desc, 'NULL') AS state_desc, 
  ISNULL(m.mirroring_state_desc, 'NULL') AS mirroring_state_desc, 
  ISNULL(m.mirroring_role_desc, 'NULL') AS mirroring_role_desc, 
  ISNULL(m.mirroring_witness_state_desc, 'NULL') AS mirroring_witness_state_desc 
FROM sys.databases AS d WITH (NOLOCK)
INNER JOIN sys.database_mirroring AS m WITH (NOLOCK)
ON d.database_id = m.database_id
"
$SqlCmd.Connection = $Connection
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd
$DataSet = New-Object System.Data.DataSet
$SqlAdapter.Fill($DataSet) > $null
$Connection.Close()

#Получили список баз. Записываем в переменную. / We get a list of databases. Write to the variable.
$baselist = $DataSet.Tables[0]

#Парсим и передаем список баз в zabbix. / Parse and pass a list of databases in zabbix.
$idx = 1
write-host "{`"data`":[`n"
foreach ($base in $baselist)
{
  if ($idx -lt $baselist.Rows.Count)
  {
    $line= "    { 
      `"{#DBNAME}`" : `"" + $base.name + "`", 
      `"{#DBMODEL}`" : `"" + $base.recovery_model_desc + "`", 
      `"{#DBSTATE}`" : `"" + $base.state_desc + "`", 
      `"{#MSTATE}`" : `"" + $base.mirroring_state_desc + "`",
      `"{#MROLE}`" : `"" + $base.mirroring_role_desc + "`",
      `"{#MWITNESS}`" : `"" + $base.mirroring_witness_state_desc + "`"
    }," | convertto-encoding "cp866" "utf-8"
    write-host $line
  }
  elseif ($idx -ge $baselist.Rows.Count)
  {
    $line= "    { 
      `"{#DBNAME}`" : `"" + $base.name + "`", 
      `"{#DBMODEL}`" : `"" + $base.recovery_model_desc + "`", 
      `"{#DBSTATE}`" : `"" + $base.state_desc + "`", 
      `"{#MSTATE}`" : `"" + $base.mirroring_state_desc + "`",
      `"{#MROLE}`" : `"" + $base.mirroring_role_desc + "`",
      `"{#MWITNESS}`" : `"" + $base.mirroring_witness_state_desc + "`"
    }" | convertto-encoding "cp866" "utf-8"
    write-host $line
  }
  $idx++;
}
write-host "]}"
