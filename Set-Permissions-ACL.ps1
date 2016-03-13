function Set-Permission {
    <#
        .SYNOPSIS
            Add / Remove NTFS rights to files or folders

        .DESCRIPTION
            Modifies ACLs of folders and files using Get-Acl and Set-Acl.
            Created by Jason Svatos
            Created on 3/10/2016
            Modified 3/12/2016 (Added EnableInheritance switch parameter and Action:Replace parameter)
            Modified 3/13/2016 (Added recurse and changed error catching on settting permissions)

        .EXAMPLE
            Set-Permission -Path C:\Temp -User domain\user -Permission FullControl
            This will append the FullControl permission to the folder C:\Temp for account domain\user

        .EXAMPLE
            Set-Permission -Path C:\Temp\Test -User Administrator -Permission FullControl -Action Replace
            This will replace all permissions on the folder "Test" with FullControl for the local Administrator account only

        .EXAMPLE
            Set-Permission -Path C:\Software -User domain\user -Permission ReadAndExecute -Action Remove -Recurse
            This will remove the ReadAndExecute permission for account domain\user on the folder C:\Software. 

        .EXAMPLE 
            Get-ChildItem c:\temp | Set-Permission -User domain\user -Permission ReadAndExecute -Recurse -inherit
            This will add ReadAndExecute permissions for domain\user to all files, folders, and subfolders under c:\temp.
            It will set inheritance on those folders for that account as well (Container Inherit and Object Inherit). 

        .PARAMETER Path
            Path of the file or folder to change permissions on

        .PARAMETER User
            "Domain\Username" of the account to add/remove rights for

        .PARAMETER Permissions
            Permissions to grant to the user

        .PARAMETER Action
            Add: Add permissions to the folder / file only for the specified account

            Replace: Replace the permissions that exist on the file or folder. This will remove all entries and overwrite with the permission(s) / account specified.
            **Warning! Using this can cause issues if you remove permissions for yourself, system, or admins.

            Remove: Remove the specified Permission(s) for the specified account on the folders/files

        .PARAMETER Inherit
            Set permissions to inherit to subdirectories/files

        .PARAMETER Recurse
            Apply permissions to all subfolders and files below specified directory

        .PARAMETER EnableInheritance
            Allow inheritance to work on the folder/file specified. This will re-enable inheritance on folders/files that have been changed with the "Replace" action.
            ** Overrides the "Replace" Action which removes inheritance
    #>

    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        [parameter(Mandatory=$true,
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [Alias("FullName","Location")]
        [String[]]$Path,

        [parameter(Mandatory=$true)]
        [String]$User,

        [parameter(Mandatory=$true)]
        [ValidateSet("AppendData","ChangePermissions","CreateDirectories","CreateFiles","Delete",
            "DeleteSubdirectoriesAndFiles","ExecuteFile","FullControl","ListDirectory","Modify",
            "Read","ReadAndExecute","ReadAttributes","ReadData","ReadExtendedAttributes",
            "ReadPermissions","Synchronize","TakeOwnership","Traverse","Write","WriteAttributes",
            "WriteData","WriteExtendedAttributes")]
        [String[]]$Permissions,

        [Switch]$Recurse,

        [parameter(Mandatory=$false,
            HelpMessage="Add; Remove; or Replace permissions. Default is Add")]
        [ValidateSet("Add","Remove","Replace")]
        [string]$Action = "Add",
        
        [Switch]$Inherit,

        [Switch]$EnableInheritance
    )

    Begin {
        $ErrorActionPreference = "Stop"

        # Create function for using with -recurse parameter
        # loopes through all sub-directories and gathers file and folder names
        function Get-SubFolders($directory) {
            # Create array to put files and directories in
            # This needs to be cleared on each iteration of the function or it will return duplicate objects
            [System.Collections.ArrayList]$subItems = @()
            try {
                # Get all files in the directory
                foreach ($f in [System.IO.Directory]::GetFiles($directory))
                {
                    # add files to arrayList - out-Null as it outputs a count for each item added
                    $subItems.Add($f) | Out-Null
                }
                # Get all sub-directories in the directory
                foreach ($d in [System.IO.Directory]::GetDirectories($directory))
                {
                    # add directories to arrayList - out-Null as it outputs a count for each item added
                    $subItems.Add($d) | Out-Null
                    # re-run the function again to get all sub-directories and files
                    Get-SubFolders $d
                }
            }
            catch [System.UnauthorizedAccessException] {
                Write-Warning ("Unable to access {0}, Access Denied" -f $directory)
            }
            catch {
                # catch any errors
                Write-Warning $_.Exception.Message
            }
            return $subItems
        }

        if ($Recurse)
        { # check if recurse is used
            foreach ($p in $Path)
            { # loop through each item and get all files and directories in it
                
                Write-Verbose "Getting all sub files and sub folders (Recurse is on)."
                Write-Verbose "This may take some time for large directories / structures..."
                $Path = Get-SubFolders -directory $p
            }
        }
    }

    Process {
        foreach ($itemPath in $Path)
        {
            try {
                $location = (Get-Item $itemPath).FullName
            }
            catch {
                # Catch any errors as Get-Item $Location will throw a different type of error
                Write-Warning "Error getting full path of object, skipping $itemPath"
                continue
            }
            Write-Verbose "Checking information for $location ..."
            # Check if the path exists
            if (-not (Test-Path -Path $location))
            {
                Write-Warning "Path does not exist"
                continue
            }
            # do some checking to see if the path is a file or directory
            # needed for security permissions and how to work with them
            if ((Get-Item $location) -is [System.IO.DirectoryInfo])
            {
                # path points to a directory
                Write-Verbose "$location is a directory"
                # Set location type for directory - needed for creating correct FileSystemAccessRule
                $locationType = "d"
            }
            else
            {
                # path points to a file
                Write-Verbose "$location is a file"
                # set location type for file - needed for creating correct FileSystemAccessRule
                $locationType = "f"
            }

            # Create variables
            # -------------------
            # Set inherit flags to default to "none"
            $inheritance = [System.Security.AccessControl.InheritanceFlags]::None
            # set propagation flags to be "none"
            $propagation = [System.Security.AccessControl.PropagationFlags]::None

            # Get the ACL of the files/folders that exist
            # Required if appending or reqplacing
            Write-Verbose "Getting ACL of current location."
            $currentACL = Get-Acl -Path $location
        
            if ($Inherit -and $locationType -eq "d")
            {
                # Only set if it is a directory - it will cause an error if it is set on a file
                # Set inheritance
                Write-Verbose "Setting Inheritance to enable"
                $inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
            }

            try {
                # Create access rule for permissions
                # .NET Constructor: FileSystemAccessRule(String, FileSystemRights, InheritanceFlags, PropagationFlags AccessControlType)
                # See https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
                Write-Verbose "Creating FileSystemAccessRule object"
                $fileSystemAccessRule = New-Object system.security.AccessControl.FileSystemAccessRule($User,[System.Security.AccessControl.FileSystemRights]$Permissions,$inheritance,$propagation,"Allow")
            }
            catch {
                Write-Error $_.Exception.ToString()
            }

            Write-Verbose "Setting action to $Action ACL"
            
            try {
                switch($Action)
                {
                    # Add, Remove, or Replace ACL from the current ACL on the folder/file
                    "Remove" {$currentACL.RemoveAccessRuleAll($fileSystemAccessRule); Break}
                    "Replace" {
                                # check if access/inheritance rules are protected
                                if ($currentACL.AreAccessRulesProtected)
                                {
                                    $currentACL.Access | foreach {$currentACL.PurgeAccessRules($_.IdentityReference)}
                                }
                                else {
                                    # Disable inheritance from folder / file
                                    # SetAccessRuleProtection([Disable Inheritance (BOOL)], [Preserve Inherited Permissions (BOOL)])
                                    $currentACL.SetAccessRuleProtection($true,$false)
                                }
                        
                                # Add ACE to current ACL
                                $currentACL.AddAccessRule($fileSystemAccessRule)
                                Break
                            } # end replace selection bracket
                    # Add = default to catch any unexpected entries
                    DEFAULT {$currentACL.AddAccessRule($fileSystemAccessRule); Break}
                }
            }
            catch {
                Write-Error $_.Exception.ToString()
            }

            if ($EnableInheritance)
            {
                # Set inheritance to be enabled on file / folder
                $currentACL.SetAccessRuleProtection($false,$false)
            }

            # Setting ACL on object
            Write-Verbose "Setting ACL on $location"

            try {
                # "SupportsShouldProcess = $True" affects this command
                # Can use -WhatIf or -Confirm
                Set-Acl -Path $location -AclObject $currentACL
            }
            catch [System.UnauthorizedAccessException] {
                # Permissions error on file / folder
                Write-Warning "Unable to change permissions on $location"
                continue
            }
            catch {
                Write-Error $_.Exception.ToString()
            }
            
            # Show ACL output if -Verbos parameter is used
            Write-Verbose "Displaying ACL for $location"

            # Get acl and format as list, output as string and write verbose
            Write-Verbose $(Get-Acl -Path $location | fl AccessToString | Out-String)
        }
    }

    End {
        Write-Verbose "Finished!"
    }
}
