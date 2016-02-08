function Get-TaskState {
    <#
        .SYNOPSIS
            Get scheduled tasks and check the state
    #>

    param (
        [parameter( Mandatory=$true)]
        [string]$TaskName
    )

    # get the task information
    $task = Get-ScheduledTask -TaskName $TaskName
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName

    switch ($task.State)
    {
        "Running" {}
        "Ready" {}
    }
    # Use send-mailmessage to send emails
    switch ($taskInfo.LastTaskResult)
    {
        0 {Write-Host "Task completed successfully"}
        267014 {Write-Host "Task was terminated by the user"}
        267009 {Write-Host "Task is currently running"
                if ((($(get-date) - $taskInfo.LastRunTime).Hours) -ge 1) {<# send email #>}}
        2147942401 {Write-Host "Incorrect Function - script didn't exit properly or the exit code was not 0"}
        3221225786 {Write-Host "Task did not complete successfully"}
    }
}
