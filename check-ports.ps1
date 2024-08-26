<#
    .NOTES
        Tired of waiting for test-netconnection on a lot of IPs? So am I.
        If you don't have access to linux tools such as netcat, then this is faster for checking a range/block of IP addresses or servers
        The newer versions of PowerShell (5+) normally go faster with using the "quiet" mode, but this will still go faster
        
    .PARAMETER servers
        String / Array of IPs, FQDNs to connect to
        
    .PARAMETER ports
        single / array of ports to connect to
        
    .PARAMETER waittime
        Time to wait in milliseconds. Defaults to 500
        
    .EXAMPLE
        check-server-ports -servers @("google.com","bing.com","yahoo.com") -ports "443"
        Check ports for google, bing, and yahoo
#>

function check-server-ports() {
    param(
        [parameter(mandatory=$true)]$servers,
        [parameter(mandatory=$true)]$ports,
        [parameter(mandatory=$false)][int]$waittime=500
    )
    foreach ($s in $servers) {
        foreach ($p in $ports) {
            try {
                $client = New-Object -TypeName System.Net.Sockets.TcpClient
                $result = $client.BeginConnect($s,$p,$null,$null)
                $value = $result.AsyncWaitHandle.WaitOne($waittime)
                Write-Output "${s}:${p}"
                write-output "Connected: $value"
                Write-Output "----------------"
            }
            catch {
                Write-Output $_
            }
        }
    }
}



function check-office365-ports() {
    <#
      .NOTES
        the IPs change all the time so you'll have to look up what they are before running this
        
        Defaults to port 993, change to the port you actually use
    #>
    param(
        $ips = @("outlook.office365.com","13.107.6.152","13.107.9.152","13.107.18.10","13.107.19.10","13.107.128.0","23.103.160.0","23.103.224.0","40.96.0.0","40.104.0.0","52.96.0.0","111.221.112.0","131.253.33.215","132.245.0.0","134.170.68.0","150.171.32.0","157.56.232.0","157.56.240.0","191.232.96.0","191.234.6.152","191.234.140.0","204.79.197.215","206.191.224.0"),
        $port = 993
    )
    foreach ($ip in $ips) {
        $requestCallback = $null
        $state = $null
        try {
            $client = New-Object System.Net.Sockets.TcpClient($ip,$port)
            if ($client) {
                write-output "Connect $ip : $port : $($client.Connected)"
            }
        }
        catch {
            Write-Output "Connect $ip : $port : Failed"
        }
    }
}
