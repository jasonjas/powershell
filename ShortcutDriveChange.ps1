<#
    .NOTES
        Jason Svatos
        Created 10/28/2015
        Updated 11/30/2015

    .SYNOPSIS
        Check for shared folders and mapped drives which have changed
        Change location of where they point to and save them

        Contains 3 functions
        - MappedDrivesIcons
        - DesktopIcons
        - LogOutput (for internal logging)

    .DESCRIPTION
        Checks for oldPath and will change to newPath if it is found
        Will do a test on the newPath to verify that the location exists before saving the change
        Change location of log file with $logFile variable

    .EXAMPLE
        MappedDrivesIcons -oldPath "c:\users\jack" -newPath "c:\users\jill"
        Will change all the mapped drives pointing to or starting with c:\users\jack to c:\users\jill

        A drive named "pictures" pointing to "c:\users\jack\documents\pictures"
        Will change to:
        A drive named "pictures" pointing to "c:\users\jill\documents\pictures"

    .EXAMPLE
        MappedDrivesIcons -oldPath "c:\users\jack" -newPath "c:\users\jill"
        Will change all the user desktop icons pointing to or starting with c:\users\jack to c:\users\jill

        A shortcut named "pictures" pointing to "c:\users\jack\documents\pictures"
        Will change to:
        A shortcut named "pictures" pointing to "c:\users\jill\documents\pictures"
        
#>

# Set error action preference to stop
$ErrorActionPreference = "Stop"

# Log file location
$logFile = "$env:LOCALAPPDATA\ShortcutChange.txt"

function MappedDrivesIcons {
    <#
    .DESCRIPTION
        Check map drives and change them if they meet requirements for where variables to point to
    
    .EXAMPLE        
        MappedDrivesIcons -oldPath "\\server\share" -newPath "\\server2\share"

        Here we are searching for any MAPPED DRIVE that contains "\\server\share" and changing it to "\\server2\share"
    #>

    param (
        # Drive location to find / replace
        [parameter(Mandatory=$true,HelpMessage="String to match which currently exists (old share)")][string]$oldPath,
        # Location to change to
        [parameter(Mandatory=$true,HelpMessage="String to change for new share")][string]$newPath
    )


    #Check for mapped drives
    try {
        $oldPath = $oldPath.ToLower()
        # add space for easier log reading
        Write-Output "" | Out-File $logFile -Append
        LogOutput -InputObject "---------- Starting MappedDrivesIcons Function... Searching for $oldPath --------" -FilePath $logFile -Append

        # Check if single or double slashes and include in string for regex -match operator        
        $oldPathRegex = $oldPath.Replace("\","\\")
        # check if "$" in string and change to \$ for regex -match operator        
        $oldPathRegex = $oldPathRegex.Replace("$","\$")        

        # put drives in variable        
        $mappedDrives = gwmi Win32_MappedLogicalDisk
        # put network connections in variable
        # some drives that cannot connect do not show up in MappedLogicalDisk
        $networkConn = gwmi Win32_NetworkConnection                 
        if (($mappedDrives.count -eq 0) -and ($networkConn.Count -eq 0))
        {
            # Quit if no mapped drives
            Write-Output "No mapped drives exist - exit script" | Out-File $logFile -Append
            # Return to get out of function
            return
        }
    }
    catch {
        LogOutput -InputObject "Error getting mapped drives" -FilePath $logFile -Append
        LogOutput -InputObject $_.Exception.Message.ToString() -FilePath $logFile -Append
    }
    
    # Begin Looping through Mapped Drives
    foreach ($drive in $mappedDrives)
    {
        # Loop through each mapped drive
        try {
            # get drive path and set to lowercase
            $drivePath = $drive.ProviderName.ToLower()
            # get drive letter
            $driveLetter = $drive.DeviceID
            # check if drive is on $oldPath
            if ($drivePath -match $oldPathRegex)
            {                
                # write to log file that a match has been found                    
                LogOutput -InputObject "*** Match found (Drive): $driveLetter, $drivePath" -FilePath $logFile -Append                
                if (-not ($drivePath -eq $oldPath))
                {
                    # Get extra folders/files by trimming the beginning path from the $drivePath
                    $extraText = $drivePath.TrimStart($oldPath)
                    LogOutput -InputObject "Trimming $oldPath and adding on $extraText" -FilePath $logFile -Append
                    $newPathChanged = Join-Path -Path $newPath -ChildPath $extraText                    
                    LogOutput -InputObject "Changing $newPath to $newPathChanged" -FilePath $logFile -Append
                }

                # if no extra text, set $newPathChanged to $newPath
                else
                {
                    $newPathChanged = $newPath                    
                }

                # test new path and write to log / skip changing if
                # it cannot connect to new shortcut path
                if (!(Test-Path $newPathChanged))
                {
                    LogOutput -InputObject "*** Cannot connect to $newPathChanged, not changing this drive." -FilePath $logFile -Append                    
                    continue
                }                                

                # Replace oldPath
                $newDrivePath = $oldPath
                $newDrivePath = $newDrivePath.Replace($drivePath, $newPathChanged)
                $newDrivePath

                # Remove Old Drive - answer "no" to force close a connection to the drive
                net use /d $driveLetter /no | Out-File $logFile -Append
                # Wait 3 seconds for old drive to be removed
                # this allows the name of the old drive to be changed accordingly
                LogOutput -InputObject "Waiting 3 seconds..." -FilePath $logFile -Append
                sleep 3
                # Map new drive
                net use $driveLetter $newDrivePath /persistent:yes | Out-File $logFile -Append
                # Write success info
                LogOutput "Successfully mapped $newDrivePath to $driveLetter." -FilePath $logFile -Append
            }
        }
        catch {
            Write-Output "Error parsing through mapped drives" | Out-File $logFile -Append
            LogOutput -InputObject $_.Exception.Message.ToString() -FilePath $logFile -Append
        }
    }
    # End looping through Mapped Drives
    
    # Begin looping through Network Connections
    foreach ($conn in $networkConn)
    {        
        # Loop through each network connection and change
        try {            
            # get RemotePath of connection
            $connPath = $conn.RemotePath.ToLower()
            # get LocalName of connection (e.g. Z:\)
            $connLetter = $conn.LocalName
            
            # test if $connPath matches $oldPathRegex
            if ($connPath -match $oldPathRegex)
            {
                LogOutput -InputObject "*** Match found (Connection): $connLetter, $connPath" -FilePath $logFile -Append
                if (-not ($connPath -eq $oldPath))
                {
                    # get extra text in the folder/file path
                    $extraText = $connPath.TrimStart($oldPath)
                    LogOutput -InputObject "Trimming $oldPath and adding on $extraText" -FilePath $logFile -Append
                    # join the paths
                    $newPathChanged = Join-Path -Path $newPath -ChildPath $extraText                    
                    LogOutput -InputObject "Changing $newPath to $newPathChanged" -FilePath $logFile -Append
                } 
                # if no extra text, set $newPathChanged to $newPath
                else
                {
                    $newPathChanged = $newPath                    
                }
                # test new path and write to log / skip changing if
                # it cannot connect to new shortcut path
                if (!(Test-Path $newPathChanged))
                {
                    LogOutput -InputObject "*** Cannot connect to $newPathChanged, not changing this drive." -FilePath $logFile -Append                    
                    continue
                }
                
                # Replace oldPath
                $newConnPath = $oldPath
                $newConnPath = $newConnPath.Replace($connPath, $newPathChanged)
                # print newConnPath
                $newConnPath
                
                # Map new drive or network connection based on variables above
                if ($connLetter -eq $null)
                {
                    # assume a network connection
                    # remove old connection
                    net use /d $connPath
                    # wait 3 seconds
                    sleep 3
                    # connect new connection
                    net use $newConnPath /persistent:yes | Out-File -FilePath $logFile -Append
                    LogOutput -InputObject "Removed $connPath and connected $newConnPath..." -FilePath $logFile -Append
                }
                else
                {
                    # assume a mapped drive
                    # remove old drive
                    net use /d $connLetter
                    # wait 3 seconds
                    sleep 3
                    # map new drive
                    net use $connLetter $newConnPath /persistent:yes | Out-File -FilePath $logFile -Append
                    LogOutput -InputObject "Removed $connLetter, $connPath and connected $newConnPath..." -FilePath $logFile -Append                    
                }
                # set new RemotePath to what it should be
                $conn.RemotePath = $newConnPath
                LogOutput "Successfully changed $connPath to $newConnPath." -FilePath $logFile -Append
            }
        }
        catch {
            LogOutput -InputObject "Error parsing through network connections" -FilePath $logFile -Append
            LogOutput -InputObject $_.Exception.Message.ToString() -FilePath $logFile -Append
        }        
    } 
    # End looping through Network Connections
}
# End MappedDrivesIcons


function DesktopIcons {
    <#
    .DESCRIPTION
        Check for icons with specified paths and change to new path.
        Will change every instance of $oldPath to $newPath - check Example 2

    .EXAMPLE
        DesktopIcons -oldPath "\\server1\share1" -NewPath "\\server2\share2"
        Will find shortcuts (.lnk) with "\\server1\share1" and replace with "\\server2\share2"
    #>

    param (        
        [parameter(Mandatory=$true, HelpMessage="Old Path to look for in shortcut")][string]$oldPath,
        [parameter(Mandatory=$true, HelpMessage="New Path to change in shortcut")][string]$newPath
    )
    
    try {
        # set oldPath to lowercase for easier matching
        $oldPath = $oldPath.ToLower()
        # Write header to log
        # add space for easier log reading
        Write-Output "" | Out-File $logFile -Append
        LogOutput -InputObject "---------- Starting DesktopIcons Function... Searching for $oldPath ----------" -FilePath $logFile -Append

        # Check if single or double slashes and include in string for regex -match operator
        $oldPathRegex = $oldPath.Replace("\","\\")
        # check if "$" in string and change to \$ for regex -match operator
        $oldPathRegex = $oldPathRegex.Replace("$","\$")
        

        # Check for shortcuts on desktop
        $desktop = [System.Environment]::GetFolderPath("Desktop")
        # Get all .lnk files from desktop
        $desktopItems = gci $desktop\*.lnk        

        # Create object to get target properties for lnk files
        $obj = New-Object -ComObject Wscript.Shell
    }
    catch {
        # catch any errors with getting information
        # catch any errors and output to log file
        Write-Output "Error replacing strings or getting shortcuts" | Out-File $logFile -Append
        LogOutput $_.Exception.Message.ToString() -FilePath $logFile -Append        
    }

    # Loop through each item
    foreach ($item in $desktopItems)
    {
        try {
            # get shortcut into variable
            $shortcut = $obj.CreateShortcut($item.FullName)
            # get shortcut's TargetPath into a variable
            $targetPath = $shortcut.TargetPath.ToLower()            
                        
            #Write-Host "$item - $targetPath"

            if ($targetPath -eq $null)
            {
                # Continue foreach to bypass blank / null object
                continue
            }

            # check if $targetPath matches $oldPath
            if ($targetPath -match $oldPathRegex)
            {
                # write to log file that a match has been found
                LogOutput "*** Match found: $item, $targetPath" -FilePath $logFile -Append                

                # check if $oldPath matches $targetPath exactly - if not, add on extra folders/files
                if (! ($targetPath -eq $oldPath))
                {                    
                    # strip $oldPath from $targetPath and get remaining text
                    # Use Replace (because of string) and not TrimStart (uses char[] array which strips more than necessary)
                    $extraText = $targetPath.Replace($oldPath,"")
                    $targetPath
                    LogOutput -InputObject "Removing $oldPath and adding on $extraText" -FilePath $logFile -Append                   
                    # Join the paths of $newPath and $extraText
                    # Use Join-Path to make sure the "\" is after $newPath and it can be reached
                    $newPathChanged = Join-Path -Path $newPath -ChildPath $extraText                    
                }
                # if no extra text, set $newPathChanged to $newPath
                else
                {
                    $newPathChanged = $newPath
                }

                # test new path and write to log / skip changing if
                # it cannot connect to new shortcut path
                if (!(Test-Path $newPathChanged))
                {
                    LogOutput "*** Cannot connect to $newPath, not changing this shortcut." -FilePath $logFile -Append                    
                    continue
                }

                # set newTargetPath to oldPath
                $newTargetPath = $targetPath               
                # Replace oldPath with newPath - 1st instance of it
                $newTargetPath = $newTargetPath.Replace($targetPath,$newPathChanged)
                # set shortcut to changed newTargetPath
                $shortcut.TargetPath = $newTargetPath
                # save the shortcut
                $shortcut.Save()

                # write to log file that the shortcut was changed successfully                
                LogOutput "$targetPath changed to $newTargetPath" -FilePath $logFile -Append
            }            
        }
        catch {
            # catch any errors and output to log file
            LogOutput -InputObject "Error getting target path for $item" -FilePath $logFile -Append
            LogOutput -InputObject $_.Exception.ToString() -FilePath $logFile -Append            
        }
    }
}

# function to create output on console and to log file
# Tee-Object does not support -Append on v1 or v2
function LogOutput {
    <#
    .DESCRIPTION
        Redirect output to a text file and to the console

    .EXAMPLE
        Write-Output "hello" | LogOutput -FilePath "c:\temp\Log.txt" -Append

    .EXAMPLE
        LogOutput -InputObject "hello" -FilePath "c:\temp\Log.txt" -Append
    #>

    param (
        [parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$InputObject,
        [parameter(Mandatory=$true)][string]$FilePath,
        [parameter(Mandatory=$false)][switch]$Append
    )

    if ($append)
    {
        # write data to file and append
        Out-File -FilePath $FilePath -InputObject $InputObject -Append
    }
    else
    {
        Out-File -FilePath $FilePath -InputObject $InputObject
    }
    # write data to console
    Write-Output $InputObject
}
