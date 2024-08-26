function Get-ChangedFiles {
    <#
        .SYNOPSIS
            Get list of folders / files in a directory by LastAccessTime or LastWriteTime
            Uses Get-ChildItem to go through folders/files and return based on parameters
            Powershell 2.0+

        .PARAMETER Path
            [String] - Required
            Directory path where to get folders / files from

        .PARAMETER Before
            [string] object for folders / files that were last accessed / written before the date
            Example 1/1/2015
            Example 1/1/15
            Example 1-1-2015
            Example 1-1-15

        .PARAMETER After
            [string] object for folders / files that were last accessed / written after the data
            Example 1/1/2015
            Example 1/1/15
            Example 1-1-2015
            Example 1-1-15

        .PARAMETER Access
            [Switch] Get folders / files where the LastAccessTime is before/after a date specified
            Requires either Before or After parameter

        .PARAMETER Write
            [Switch] Get folders / files where the LastWriteTime is before/after a date specified
            Requires either Before or After parameter

        .PARAMETER Folders
            [Switch] Only show folders

        .PARAMETER Files
            [Switch] Only show files

        .PARAMETER Recurse
            [Switch] Recurse through sub directories

        .EXAMPLE
            Get-ChangedFiles -Path C:\Temp -Before "1/1/2015" -Access
            Will get all files and folders that were the LastAccessTime is before 1/1/2015 in the C:\Temp folder

        .EXAMPLE
            Get-ChangedFiles -Path C:\Temp -After "1/1/2015" -Write -Recurse -Files
            Will get all files that were last written after 1/1/2015
            Gets all files below the C:\Temp directory

        .EXAMPLE
            Get-ChangedFiles C:\Temp -Folders
            Gets all the folders in C:\Temp

        .NOTES
            Created by Jason Svatos
            1/30/2016
    #>

    # Declare parameters
    [CmdletBinding()]
    param (
            [parameter( Mandatory=$true,
                        Position=1,
                        HelpMessage="String - Path to the folder that you want to get contents of")]
            [string]$Path,
        
            [parameter( Mandatory=$true,
                        ParameterSetName="before",
                        HelpMessage="A string that can be converted to DateTime - 01/01/16, 01/01/2016, 01-01-16, or 01-01-2016")]            
            [ValidatePattern("^\d{1,2}(-|\/)\d{1,2}(-|\/)(?:\d{4}|\d{2})$")]
            [string]$Before,

            [parameter( Mandatory=$true,
                        ParameterSetName="after",
                        HelpMessage="A string that can be converted to DateTime - 01/01/16, 01/01/2016, 01-01-16, or 01-01-2016")]
            [ValidatePattern("^\d{1,2}(-|\/)\d{1,2}(-|\/)(?:\d{4}|\d{2})$")]            
            [string]$After,

            [parameter( Mandatory=$false,
                        ParameterSetName="before")]
            [parameter( Mandatory=$false,
                        ParameterSetName="after")]
            [switch]$Access,

            [parameter( Mandatory=$false,
                        ParameterSetName="before")]
            [parameter( Mandatory=$false,
                        ParameterSetName="after")]
            [switch]$Write,

            [parameter( Mandatory=$false)]
            [switch]$Folders,

            [parameter( Mandatory=$false)]
            [switch]$Files,

            [parameter( Mandatory=$false)]
            [switch]$Recurse
    )

    Begin {
        # Declare variables
        #$ErrorActionPreference = "stop"

        # Default the files changed to LastWriteTime
        # If user doesn't select $Write or $Access, it will default to this
        $fileChangedProperty = "LastWriteTime"

        # create error code for capturing errors
        [int]$errorCode = 0

        Write-Host "Adding all items in path to an array, please wait"
        Write-Host ""
    }

    Process {
        try {
            if (-not (Test-Path $Path))
            {
                throw [System.IO.FileNotFoundException] "Path not found"
            }
            if ($Recurse)
            {
                # get all items and sub folders from $Path
                $folderItems = Get-ChildItem -Path $Path -Recurse
            }
            else
            {
                # get all items just in the $Path folder
                $folderItems = Get-ChildItem -Path $Path
            }
        }
        catch [UnauthorizedAccessException] {
            # Access Denied Error - ignore
            Write-Host -ForegroundColor Red "Access Denied on $_.TargetObject.ToString()"            
        }
        catch [System.IO.FileNotFoundException] {
            # path not found - exit
            Write-Host -ForegroundColor Red "Path not found"
            $errorCode = -1            
            return
        }
        catch {
            # Error with Get-ChildItem
            Write-Host "Error with Get-ChildItem"
            Write-Host $_.Exception
            $errorCode = -1
            return
        }

        try {
            # setup a filter for objects that will be used to get the results the user is wanting
            if ($Access)
            {
               # if $Access is selected, set the property to search for to LastAccessTime
               # Default is LastWriteTime - which is $Write
               $fileChangedProperty = "LastAccessTime"
            }

            # set the date to search beginning / ending from
            if ($Before)
            {
                # convert string to DateTime
                [DateTime]$date = $Before
                # string for console output information
                $timeFrame = "before"
                # write information to console
                Write-Host "Getting files/folders with $fileChangedProperty $timeFrame $date"
                # Filter out the items that match the date BEFORE the input date
                $folderItems = $folderItems | Where-Object {$_.$fileChangedProperty -lt $date}
            }
            if ($After)
            {
                # convert string to DateTime            
                [DateTime]$date = $After
                # string for console output information
                $timeFrame = "after"
                # write information to console
                Write-Host "Getting files/folders with $fileChangedProperty $timeFrame $date"
                # Filter out the items that match the date AFTER the input date
                $folderItems = $folderItems | Where-Object {$_.$fileChangedProperty -gt $date}
            }

            if ($files)
            {
                # filter out the items that match only files
                Write-Host "Selecting only the files"
                $folderItems = $folderItems | Where-Object {$_.PSisContainer -eq $false}
            }
            if ($Folders)
            {
                # filter out the items that match only folders
                Write-Host "Selecting only the folders"
                $folderItems = $folderItems | Where-Object {$_.PSisContainer -eq $true}
            }
        }
        catch {
            # error sorting data
            $_.Exception.ToString()
            $errorCode = -1
            return
        }
    }

    End {        
        if ($errorCode -ne 0)
        {
            # return an error code that caused the program to stop
            return $errorCode
        }
        else
        {
            # Return all the folders or files that have been selected
            return $folderItems
        }
    }
}
