Import-Module awspowershell

function AWS-Backup {
    <#
        .SYNOPSIS
            Backup files to S3 based on locations in a text file
            Can back up individual files or whole directories
            Requires AWS Credentials to be configured prior to running script.
            See https://docs.aws.amazon.com/powershell/latest/reference/items/Set-AWSCredentials.html 
            
        .DESCRIPTION
            Will store file hashes in a text file and compare each time the file is backed up.
            If any changes in directory, the whole directory will be re-uploaded. 
            Will have to specify full location to each file if you want to upload manually instead. 

        .NOTES
            Requires AWS Powershell cmdlets
            See https://aws.amazon.com/powershell/
            Requires AWS Credentials to be configured prior to running script.
            See https://docs.aws.amazon.com/powershell/latest/reference/items/Set-AWSCredentials.html

        .PARAMETER AwsCredentials
            Saved AWS Credential

        .PARAMETER region
            Region to upload files to

        .PARAMETER ConfigFile
            Path to list of hashes for existing files, or path to store the hashes for files. 

        .PARAMETER bucketName
            Name of bucket in S3 to upload files to

        .PARAMETER backupFilesList 
            Path to location of files/directories to backup

        .PARAMETER FullRefresh
            Removes ConfigFile hash list and re-uploads all files/directories whether they have been uploaded previously or not
    #>
    param (
        [parameter(mandatory=$false,
                   Position=0)]
        [String]$AwsCredentials="",
        [String]$region = "",
        [String]$ConfigFile = "",
        [String]$bucketName = "",
        [String]$backupFilesList = "",
        [Switch]$FullRefresh
    )

    if ($FullRefresh) {
        if ([System.IO.File]::Exists($ConfigFile)) {Remove-Item $ConfigFile}
    }

    Set-AWSCredentials -StoredCredentials $AwsCredentials
    Set-DefaultAWSRegion $region
    # special characters that do not show up correctly in the text file
    # Will be used to replace characters later
    $backupFiles = gc $backupFilesList

    function BackupFiles() {
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
                        $folderChange = 1
                    }
                }
                if ($folderChange -ne 0) {
                    Write-Output "Uploading folder $file"
                    Write-S3Object -BucketName $bucketName -Folder $file -KeyPrefix $keyprefix -Recurse
                }
                else {Write-Output "No change for $file"}
            }
            else 
            {
                # is a file
                if ((Set-FileHash -Path $file) -ne $null) {
                    Write-Output "Uploading file $file"
                    Write-S3Object -BucketName $bucketName -File $file
                }
                else {Write-Output "Skipping $file"}
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
        #>

        param(
            [parameter(Mandatory=$true)]
            [String]$Path
        )
    
        # set change if hash CSV file is updated
        [int]$change = 0

        $SpecChars = '!', '£', '%', '&', '^', '*', '@', '=', '+', '¬', '`', '<', '>', '?', ';', '#', '~', '®', 'é', '–', "'", '"', "’", "[", "]"
        $remspecchars = [string]::join('|', ($SpecChars | % {[regex]::escape($_)}))

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
