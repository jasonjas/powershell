function Set-Permissions {
    <#
        .SYNOPSIS
            Set permissions on folder(s) that are either defined or piped in. Must be a string or array.
            Can give multiple users/groups access by specifying multiple users in string-array format.

        .DESCRIPTION
            Uses the basic syntax of icacls.exe to add / remove permissions to folders and/or files.

        .NOTES
            Created By Jason Svatos
            Created on 2/4/2016
            Version 1

        .PARAMETER Folder
            Directory / Folder(s) that will be changed with the user(s) and permission specified

        .PARAMETER User
            The User(s) that will be added / removed from the permissions

        .PARAMETER Permission
            DYNAMIC PARAMETER
            Only shows up / required when using grant / deny PermSetting parameter
            Can only specify the simple rights for NTFS permissions. If you want specific rights, you must use something else.
            Can only use these letters:

            N - no access
            F - full access
            M - modify access
            RX - read and execute access
            R - read-only access
            W - write-only access
            D - delete access

        .PARAMETER PermSetting
            Used to either grant, deny, or remove permissions.
            Can be either Grant, Deny, or Remove. Default is Grant.

        .PARAMETER Inheritance
            Use to specify that you want inheritance on the folder(s) and files for these permissions. 
            Will use both Container Inherit (CI) and Object Inherit (OI)

        .PARAMETER Recurse
            Use to specify you want all sub-folders and files to have these same permissions / changes applied.

        .PARAMETER Quiet
            Use to suppress success messages on the console.

        .PARAMETER Replace
            Can only be used with "Grant" PermSetting
            Replaces all other permissions with just this permission.

        .PARAMETER DenyCriteria
            Can be either "grant" or "deny". Used only with "remove" on PermSetting parameter.
            This will remove either Granted or Denied permissions. Default is to remove Granted permissions.
    #>

    <#
        # Old parameter - it is a dynamic parameter now
        [parameter( Mandatory=$true)]
        [ValidateSet("N","F","M","RX","R","W","D")]                    
        [string]$Permission,
    #>

    param (
        [parameter( Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=0)]
        [Alias("Directory","Path")]
        [string[]]$Folder,

        [parameter( Mandatory=$true,
                    Position=1)]
        [string[]]$User,

        [parameter( Mandatory=$false,
                    Position=2,
                    HelpMessage="Use to declare to either Grant / Deny / Remove permissions. Default is Grant.")]
        [ValidateSet("grant","remove","deny")]
        [string]$PermSetting = "grant",

        [switch]$Inheritance=$true,
        
        [switch]$Recurse,

        [switch]$Quiet,

        [parameter( Mandatory=$false,
                    HelpMessage="Use to replace granted rights when using 'grant' PermSetting")]        
        [switch]$Replace,
        
        [ValidateSet("grant","deny")]
        [string]$DenyCriteria = "grant"
    )

    # Create Dynamic Parameter for Permissions
    DynamicParam {
        # This will create a parameter which is only required if $PermSetting is anything but "deny"
        if ($PermSetting -ne "remove")
        {
            # Create parameter Attribute object
            $permissionAttribute = New-Object System.Management.Automation.ParameterAttribute
            $permissionAttribute.Mandatory=$true
            $permissionAttribute.HelpMessage="Enter simple permission to Grant / Remove from folder(s) / file(s). Can be only [N,F,M,RX,R,W,D].
            For more granular control of permissions, use icacls.exe instead."
            # Create array of valid values to allow on the parameter
            [string[]]$validValues = @("N","F","M","RX","R","W","D")
            # create Valid values for the parameter
            $permissionValidate = New-Object System.Management.Automation.ValidateSetAttribute($validValues)

            # Create an atribute collection object for the attribute we just created
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

            # Add the custom attributes to the collection
            $attributeCollection.Add($permissionAttribute)
            # Add the validate set attributes to the collection
            $attributeCollection.Add($permissionValidate)

            # Add the parameter specifying the attribute collection
            # This defines the name of the parameter, the type, and the attributes (String, Type, Attributes)
            $permissionParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Permission', [string], $attributeCollection)

            # Expose the name of our dynamic parameter
            # Create run-time parameter dictionary
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            # Add the parameter name and runtime parameter
            $paramDictionary.Add('Permission',$permissionParam)
            return $paramDictionary
        }
    }

    Begin {
        # Variables

        # Map dynamic parameter to Permission variable
        $Permission = $PSBoundParameters.Permission
        
        # Create variables to make the below foreach loops easier to create and maintain/update

        try {
            # Set permissions up based on inheritance switch        
            if ($Inheritance) {$perm = ":(OI)(CI)$Permission"}        
            else {$perm = ":$Permission"}

            # set permission settings and occurrences based on PermSetting for "REMOVE"
            if ($PermSetting -eq "remove")
            {
                # removing permissions removes the user completely, not just specific permissions
                $perm = ""
                if ($DenyCriteria -ne "grant")
                {
                    # Removes only denied permissions
                    $permissionCriteria = ":d"
                }
                else {
                    # Removes only granted permissions
                    $permissionCriteria = ":g"
                }
            }

            # Set Permission setting (Remove / Deny / Grant)
            #  to correct string
            $PermissionSetting = "/" + $PermSetting
        }
        catch {
            # Catch any issues
            $_.Exception.ToString()
            Read-Host "Error creating variables"
            return -1
        }
    }

    Process {
        try {
            # loop through users to apply permissions for
            foreach ($u in $User)
            {
                # loop through folders to apply permissions to
                foreach ($f in $Folder)
                {
                    # if recurse is chosen
                    if ($Recurse)
                    {
                        # add / remove permissions and continue on errors
                        icacls.exe $f $($PermissionSetting  + $permissionCriteria) ("$User" + "$perm") /T /C
                    }
                    # if recurse is not chosen
                    else 
                    {
                        # add / remove permissions and continue on errors
                        icacls.exe $f $($PermissionSetting  + $permissionCriteria) ("$User" + "$perm") /C
                    }
                }
            }
        }
        catch {
            # catch any errors
            $_.Exception.ToString()
            Read-Host "Error applying permissions"
            return -1
        }
    }
}
