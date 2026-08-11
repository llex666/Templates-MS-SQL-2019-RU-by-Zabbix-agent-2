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

$ver = Invoke-Sqlcmd -Query "SELECT @@VERSION;" -QueryTimeout 3 
$vercol = $ver.Column1 | convertto-encoding "cp866" "utf-8"

write-host $vercol