function check-server-ports() {
    <#
        .SYNOPSIS
            Check if ports are open - much faster than test-netconnection

        .PARAMETER servers
            The FQDN / IPs to scan

        .PARAMETER ports
            The port(s) to scan

        .PARAMETER timeout
            The amount of seconds to wait before no results are returned (timed out)

        .EXAMPLE
            check-server-ports -servers @("office.microsoft.com","google.com") -ports @(80, 443, 990)

        .EXAMPLE
            check-server-ports -servers "10.1.2.3" -ports 22
    #>
    param(
        [parameter(mandatory=$true)][string[]]$servers,
        [parameter(mandatory=$true)][int[]]$ports,
        [parameter(mandatory=$false)][int]$timeout=2
    )
    foreach ($s in $servers) {
        foreach ($p in $ports) {
            try {
                $client = New-Object -TypeName System.Net.Sockets.TcpClient
                $result = $client.BeginConnect($s,$p,$null,$null)
                $value = $result.AsyncWaitHandle.WaitOne([System.TimeSpan]::FromSeconds($timeout))
                Write-Output "${s}:${p}"
                write-output "Connected: $value"
                Write-Output "----------------"
                if ($value) {
                    $client.EndConnect($result)
                }
                $client.Close()
            }
            catch {
                Write-Output $_
                $client.close()
            }
        }
    }
}
