Import-Module awspowershell

function AWS-Backup {
    param (
        [parameter(mandatory=$false,
                   Position=0)]
        [String]$AwsCredentials="jasonjas",
        [String]$region = "us-east-1",
        [String]$ConfigFile = "F:\UserFiles\BackupFileHash.config",
        [String]$bucketName = "jasonsvatos-backup",
        [String]$backupFilesList = "C:\Users\jason\Desktop\BackupFilesS3.txt"
    )

    Set-AWSCredentials -StoredCredentials $AwsCredentials
    Set-DefaultAWSRegion $region
    # special characters that do not show up correctly in the text file
    # Will be used to replace characters later
    $SpecChars = '!', '£', '%', '&', '^', '*', '@', '=', '+', '¬', '`', '<', '>', '?', ';', '#', '~', '®', 'é', '–', "'", '"', "’", "[", "]"
    $remspecchars = [string]::join('|', ($SpecChars | % {[regex]::escape($_)}))
    $backupFiles = gc $backupFilesList

    function BackupFiles() {
        #$backupfiles = gc "$desktop\BackupFilesS3.txt"
        [int]$folderChange = 0

        # backup files
        foreach ($file in $backupfiles) {
            # check for comment characters and ignore
            if ($file.Trim().StartsWith("#")) {}
            
            elseif ((Get-Item $file) -is [System.IO.DirectoryInfo]) {
                # is a directory
                # get the directory name and set as the prefix/folder to store under root bucket
                $keyprefix = [System.IO.DirectoryInfo]$file | select -ExpandProperty Name
                $folderItems = gci -Path $file -Recurse
                foreach ($item in $folderItems) {
                    # check if any items have been changed in folder, if not, skip the upload of the folder
                    if ((Get-Item $item.FullName) -is [System.IO.DirectoryInfo]) {} #do nothing
                    elseif ((Set-FileHash -Path $item.FullName) -ne $null) {
                        $s3path = $item.FullName.Substring($item.FullName.IndexOf("$keyprefix"))
                        Write-S3Object -BucketName $bucketName -File $item.FullName -Key $s3path
                        Write-Output "Uploading $($item.FullName)"
                        $folderChange = 1
                    }
                }
                if ($folderChange -eq 0) {
                    Write-Output "No change for directory $file"
                }
            }

            else 
            {
                # is a file
                if ((Set-FileHash -Path $file) -ne $null) {
                    Write-Host "Uploading file $file"
                    Write-S3Object -BucketName $bucketName -File $file
                }
                else {Write-Host "Skipping $file"}
            }
        }

        Read-Host "pause"
    }

    function Set-FileHash() {
        <#
            .SYNOPSIS
                store the file hash in a text file
                setup as:
                LOCATION:HASH

            .PARAMETER Path
                Path to the file to set the hash for

            .PARAMETER ConfigFile
                Path to location of config file containing hashes
        #>

        param(
            [parameter(Mandatory=$true)]
            [String]$Path
        )
    
        # set change if hash CSV file is updated
        [int]$change = 0

        # Check if config file exists, if not - create it
        if (-not (Test-Path $ConfigFile)) {
            New-Item -Path $(Split-Path $ConfigFile) -ItemType file -Force -Name "BackupFileHash.config" -Value "file=hash"
        }
    
        $hash = Get-FileHash -Path $Path | Select -ExpandProperty Hash
        [PSObject[]]$hashlist = @()

        # Get list of all hashes
        $hashlist = Search-FileHash -List
    
        # Remove special characters and rename how file shows up
        $Path = $Path -replace $remspecchars, ""

        # Check if file path already exists
        if ($hashlist.file -contains $Path) {
            # Path exists in file
            $rowIndex = [array]::IndexOf($hashlist.file,$Path)
            #check if hashes match
            if ($hashlist[$rowIndex].hash -eq $hash) {
                # do nothing as hashes match
                # Write-Output "No change for file: $Path"
            }
            else {
                #update hash
                Write-Output "Updating hash for file: $Path"
                $hashlist[$rowIndex].hash = $hash
                $change = 1
            }
        }
        else {
            # Create output as it does not exist in config file
            Write-Output "Creating hash for file: $Path"
            $newRow = New-Object PsObject -Property @{ hash = $hash ; file = $Path }
            $hashlist += $newRow
            $change = 1
        }

        if ($change -ne 0) {
            # Export CSV changes to config file
            $hashlist | Export-Csv $ConfigFile -NoTypeInformation
        }
    }

    function Search-FileHash() {
        <# 
            .SYNOPSIS
                search config file for object hash

            .PARAMETER Path
                Path of file to search for hash on

            .PARAMETER ConfigFile
                Path to location of config file containing hashes

            .PARAMETER List
                List hashes instead of searching for a single object

            .PARAMETER hash
                Return only the hash and not the file name
        #>
            
        param(
            [parameter(Mandatory=$false)]
            [String]$Path,
            [parameter(Mandatory=$false)]
            [Switch]$List,
            [parameter(Mandatory=$false)]
            [Switch]$hash
        )

        if (-not (Test-Path $ConfigFile)) {Write-Error "Config file not exist"}

        # list all items in config file
        $items = Import-Csv -Delimiter "," -Path $ConfigFile
        # get list of items in hash
        if ($List) {
            return $items
        }
        # search for specific hash
        else {
            $results = $items | Select-String -Pattern $Path
            return $results
        }
    }

    BackupFiles
}

AWS-Backup
