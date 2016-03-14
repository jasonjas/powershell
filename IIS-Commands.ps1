# IIS Web administration functions

Import-Module WebAdministration

function Backup-Config {
    <#
        .SYNOPSIS
            See: Get-Help Backup-WebConfiguration -Full
    #>
    param($Name)
    
    Backup-WebConfiguration -Name $Name
}

function Restore-Config {
    <#
        .SYNOPSIS
            See: Get-Help Restore-WebConfiguration -Full
    #>
    param($Name)

    Restore-WebConfiguration -Name $Name
}

function List-Backups {
    <#
        .SYNOPSIS
            List backups on the server
    #>

    Get-WebConfigurationBackup -Name *
}

function List-AppPools {
    <#
        .SYNOPSIS
            List all application pools
    #>

    Get-ChildItem -Path IIS:\AppPools
}

function List-Sites {
    <#
        .SYNOPSIS
            List all web sites
    #>
    
    Get-ChildItem -Path IIS:\Sites
}