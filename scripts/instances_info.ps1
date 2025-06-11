$server = $env:computername  
$object = Get-WmiObject win32_service -ComputerName $server  | where {($_.name -like "MSSQL$*" -or $_.name -like "MSSQLSERVER" -or $_.name -like "SQL Server (*") -and $_.name -notlike "*helper*" -and $_.name -notlike "*Launcher*"}
if ($object)
{
  $instInfo = $object | select Name, StartMode, State, Status | convertto-encoding "cp866" "utf-8"
  $instInfo
}else
{
  Write-Host "No instance found!"
}