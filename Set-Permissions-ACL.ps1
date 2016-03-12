function Set-Permission {
    <#
        .SYNOPSIS
            Add / Remove NTFS rights to files or folders

        .EXAMPLE
            Set-Permission -Path C:\Temp -User domain\user -Permission FullControl
            This will append the FullControl permission to the folder C:\Temp for account domain\user

        .EXAMPLE
            Set-Permission -Path C:\Temp\Test -User Administrator -Permission FullControl -Action Replace
            This will replace all permissions on the folder "Test" with FullControl for the local Administrator account only

        .EXAMPLE
            Set-Permission -Path C:\Software -User domain\user -Permission ReadAndExecute -Action Remove -Recurse
            This will remove the ReadAndExecute permission for account domain\user on the folder C:\Software. 

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
        [parameter(Mandatory=$true)]
        [String]$Path,

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

        # Check if the path exists
        if (-not (Test-Path -Path $Path))
        {
            Write-Verbose "Testing if $Path exists"
            throw "Path does not exist"
        }
        # do some checking to see if the path is a file or directory
        # needed for security permissions and how to work with them
        if ((Get-Item $Path) -is [System.IO.DirectoryInfo])
        {
            # path points to a directory
            Write-Verbose "$Path is a directory"
        }
        else
        {
            # path points to a file
            Write-Verbose "$Path is a file"
        }

        # Create variables
        # -------------------
        # Set inherit flags to default to "none"
        $inheritance = "none"
        # set propagation flags to be "none"
        $propagation = "none"
    }

    Process {
        # Get the ACL of the files/folders that exist
        # Required if appending or reqplacing
        Write-Verbose "Getting ACL of current path."
        $currentACL = Get-Acl -Path $Path
        
        if ($Inherit)
        {
            # Set inheritance
            Write-Verbose "Setting Inheritance to enable"
            $inheritance = "ContainerInherit,ObjectInherit"
        }

        try {
            # Create access rule for permissions
            # .NET Constructor: FileSystemAccessRule(String, FileSystemRights, AccessControlType)
            # See https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemaccessrule(v=vs.110).aspx
            Write-Verbose "Creating FileSystemAccessRule object"
            $fileSystemAccessRule = New-Object system.security.AccessControl.FileSystemAccessRule($User,$Permissions,$inheritance,$propagation,"Allow")
        }
        catch [System.ArgumentOutOfRangeException] {
            Write-Verbose $_.Exception.Message.ToString()
            return -1
        }

        Write-Verbose "Setting action to $Action ACL"
        switch($Action)
        {
            # Add, Remove, or Replace ACL from the current ACL on the folder/file
            "Add" {$currentACL.AddAccessRule($fileSystemAccessRule); Break}
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
        }

        if ($EnableInheritance)
        {
            # Set inheritance to be enabled on file / folder
            $currentACL.SetAccessRuleProtection($false,$false)
        }

        # Setting ACL on object
        Write-Verbose "Setting ACL on $Path"

        # "SupportsShouldProcess = $True" affects this command
        # Can use -WhatIf or -Confirm
        Set-Acl -Path $Path -AclObject $currentACL
    }

    End {
        Write-Verbose "Displaying ACL for $Path"
        Get-Acl -Path $Path | fl
        Write-Verbose "Finished!"
    }
}