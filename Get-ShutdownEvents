<#
    .DESCRIPTION
        Get shutdown times
#>

$count = 1
#$count = Read-Host -Prompt "results returned (default = 1)"

function Get-ShutdownEvents {
    [DateTime]$shutdowntime = Get-EventLog -LogName System -Source user32 -EntryType Information -Newest $count | select -ExpandProperty TimeGenerated
    [DateTime]$sleeptime = (Get-EventLog -LogName System -InstanceId 1 -Source Microsoft-Windows-Power-TroubleShooter -Newest $count).ReplacementStrings[0]
    echo "Last shutdown time: $shutdowntime"
    echo ""
    echo "Last sleep time: $sleeptime"
    $lastpowerchanges = Get-EventLog -LogName System -Source Microsoft-Windows-Kernel-Power -InstanceId 42 -Newest 10 | select -ExpandProperty TimeGenerated
    echo ""
    Write-Host -ForegroundColor Green "Last 10 power changes:"
    echo $lastpowerchanges
}

Get-ShutdownEvents
pause