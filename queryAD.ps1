Function Get-ADObject 
{ 
<# 
    .SYNOPSIS  
        Function allow to get AD object info without AD Module. 
        RSAT AD Module allows for more granular searching / better output.
        This is for those who can't install it due to security / permissions
 
    .DESCRIPTION  
        Use Get-ADObject to get information about Active Directory groups, users, or computers
        Defaults to domain computer is joined to
        
    .NOTES
        Original Author: Michal Gajda (https://gallery.technet.microsoft.com/scriptcenter/Export-AD-Users-properties-eea93c89)
        Modified by: Jason Svatos
        Changed: 12/11/2017
        Added searching for groups
        Added SAMAccountName attribute
        Added Members parameter for group objects
        Added Groups parameter for user objects
        Want to change the search syntax in the script? https://msdn.microsoft.com/en-us/library/aa746475(v=vs.85).aspx
        
        Changed: 2018/2019?
        Added everything else :-)
 
    .PARAMETER Domain
        The domain to search in (e.g. contoso.com or ad.contoso.com)
        *** needs to be setup if wanting to be used... defaults to computer's joined domain ***
 
    .PARAMETER ObjectType
        Type of object to search for (user, group, or computer)
        Choices = user, group or computer, defaults to user

    .PARAMETER Name
        The common name (cn) to search for. Wildcards (*) can be used
        Examples: 
            cn of John Smith would show up in one of the choices listed below:
            john.smith
            john.sm*
            *smith
            *n.smit*

    .PARAMETER SAMAccountName
        The SAMAccountName (logon name) of a user or group

    .PARAMETER members
        Output only the members of a group when a GROUP is searched for

    .PARAMETER groups
        Output only the groups a user belongs to when a USER is searched for   
        
    .PARAMETER csv
        Output to CSV, requires the OutputFile parameter

    .PARAMETER OutputFile
        Only used with csv switch. Destination of CSV file

    .PARAMETER Description
        Search for description of object, best used with wildcards
        ex: *john smith*

    .PARAMETER LockedCheck
        Check if account is locked
        
         
    .EXAMPLE  
        Get-ADObject -name john.smith -csv -outputfile c:\temp\AD-output.csv
        Search for john.smith user and export results to CSV file

    .EXAMPLE
        Get-ADObject -ObjectType group -name Developer -
        Search for Developer group

    .EXAMPLE
        Get-ADObject -domain CONTOSO -name "john sm*"
        Search for CONTOSO user account with name john sm*

    .EXAMPLE
        Get-ADObject -domain CONTOSO -SAMAccountName psmitj01
        Search for CONTOSO user account with logon name psmitj01

    .EXAMPLE
        Get-ADObject -domain CONTOSO -SAMAccountName psmitj01 -groups
        Return the group names that psmitj01 is a part of

    .EXAMPLE
        Get-ADObject -ObjectType group -name Developer -members
        Return usernames of members that are a part of group Developer

    .EXAMPLE
        Get-ADObject -ObjectType computer -name ASAMOKAN12345 -csv -OutputFile c:\temp\ASAMOKAN12345.csv
        Return information about computer name ASAMOKAN12345 and output to CSV file
 
    
#> 
    [CmdletBinding( 
        SupportsShouldProcess=$True, 
        ConfirmImpact="Low" 
    )] 
    param 
    ( 
        #[String]$domain,
        [ValidateSet("user","group","computer")][String]$ObjectType = "user",
        [Parameter(ParameterSetName='name')]
        [String]$name = $null,
        [parameter(ParameterSetName='sam')]
        [Alias("LogonName","username","user")]
        [String]$SAMAccountName = $null,
        [parameter(ParameterSetName='email')]
        [String]$email,
        [parameter(ParameterSetName='description')]
        [String]$Description,
        [parameter(ParameterSetName='distinguishedname')]
        [String]$DistinguishedName,
        [Switch]$members,
        [Switch]$groups,
        [parameter( ParameterSetName='csv')]
        [parameter(ParameterSetName='email')]
        [parameter(ParameterSetName='name')]
        [parameter(ParameterSetName='sam')]
        [parameter(ParameterSetName='description')]
        [parameter(ParameterSetName='distinguishedname')]
        [Switch]$csv,
        [parameter( ParameterSetName='csv',
                    mandatory=$true)]
        [parameter(ParameterSetName='email')]
        [parameter(ParameterSetName='name')]
        [parameter(ParameterSetName='sam')]
        [parameter(ParameterSetName='description')]
        [parameter(ParameterSetName='distinguishedname')]
        [String]$OutputFile,
        [Switch]$LockedCheck
    ) 
 
    Begin{
        $ErrorActionPreference = "stop"
        if (-not $domain) {[String]$Ldap = "dc="+$env:USERDNSDOMAIN.replace(".",",dc=")}
        else {
            <#
                **********
                Setup stuff here if domain is read. Otherwise it still chooses the default domain
                This is helpful in places where multiple domains exist
                **********
            #>
            #if ($domain -eq 'domain1') {$Ldap = "DC=site,DC=ad,DC=CONTOSO,DC=com"}
            #else {$Ldap = "OU=users,DC=CONTOSO,DC=com"}
            [String]$Ldap = "dc="+$env:USERDNSDOMAIN.replace(".",",dc=")
        }

        #default to user searching
        [String]$Filter = "(&(objectCategory=person)(objectClass=user))"

        if ($members) {
            if ($ObjectType -ne "group") {Write-Error "Can only specify members if ObjectType = group"}
            
        }
        if ($groups) {
            if ($ObjectType -ne "user") {Write-Error "Can only specify groups if ObjectType = user"}
        }

        if ($PSCmdlet.ParameterSetName -eq "name") {
            #Search with name attribute
            if ($name -eq $null) {
                if ($ObjectType -eq "computer") {$Filter = "(objectCategory=Computer)"}
                elseif ($ObjectType -eq "group") {$Filter = "(&(objectCategory=Group)(objectClass=group))"}
            }
            else {
                if ($ObjectType -eq "group") {$Filter = "(&(objectCategory=Group)(objectClass=group)(cn=$name))"}
                elseif ($ObjectType -eq "user") {$Filter = "(&(objectCategory=person)(objectClass=user)(cn=$name))"}
                elseif ($ObjectType -eq "computer") {$Filter = "(&(objectCategory=Computer)(cn=$name))"}
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "sam") {
            #Search with SamAccountName attribute
            if ($ObjectType -eq "group") {
                $Filter = "(&(objectCategory=Group)(objectClass=group)(samaccountname=$SAMAccountName))"
            }
            elseif ($ObjectType -eq "user") {
                $Filter = "(&(objectCategory=person)(objectClass=user)(samaccountname=$SAMAccountName))"
            }
            elseif ($ObjectType -eq "computer") {
                $Filter = "(&(objectCategory=Computer)(samaccountname=$SAMAccountName))"
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "email") {
            #Search with SamAccountName attribute
            if ($ObjectType -eq "group") {
                $Filter = "(&(objectCategory=Group)(objectClass=group)(mail=$email))"
            }
            else {
                $Filter = "(&(objectCategory=person)(objectClass=user)(mail=$email))"
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "description") {
            #Search with Description attribute
            if ($ObjectType -eq "group") {
                $Filter = "(&(objectCategory=Group)(objectClass=group)(description=$Description))"
            }
            elseif ($ObjectType -eq "user") {
                $Filter = "(&(objectCategory=person)(objectClass=user)(description=$Description))"
            }
            elseif ($ObjectType -eq "computer") {
                $Filter = "(&(objectCategory=Computer)(description=$Description))"
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "distinguishedname") {
            #Search with Description attribute
            if ($ObjectType -eq "group") {
                $Filter = "(&(objectCategory=Group)(objectClass=group)(distinguishednamen=$distinguishedname))"
            }
            elseif ($ObjectType -eq "user") {
                $Filter = "(&(objectCategory=person)(objectClass=user)(distinguishedname=$distinguishedname))"
            }
            elseif ($ObjectType -eq "computer") {
                $Filter = "(&(objectCategory=Computer)(distinguishedname=$distinguishedname))"
            }
        }
    }
 
    Process 
    { 
        if ($pscmdlet.ShouldProcess($Ldap,"Get information about AD Object")) 
        { 
            $searcher=[adsisearcher]$Filter 
            
            $Ldap = $Ldap.replace("LDAP://","")
            $searcher.SearchRoot="LDAP://$Ldap"
            $results=$searcher.FindAll()
     
            $ADObjects = @()
            foreach($result in $results)
            { 
                [Array]$propertiesList = $result.Properties.PropertyNames 
                $obj = New-Object PSObject 
                foreach($property in $propertiesList)
                {  
                    $obj | add-member -membertype noteproperty -name $property -value ([string]$result.Properties.Item($property)) 
                } 
                $ADObjects += $obj 
            }
            
            if ($ADObjects.samaccountname -eq $null -and $ADObjects.distinguishedname -eq $null) {return "Account does not exist"}

            if ($LockedCheck) {
                # check if account is locked out
                if ($ADObjects.lockouttime -gt 0) {return "$($ADObjects.cn) is locked out"}
                else {return "$($ADObjects.cn) is not locked"}
            }

       
            if ($members) {
                $ADObjects.member -split "CN=" | % {($_ -split ",")[0]}
            }
            elseif ($groups) {
                # return groups user is a member of
                $ADObjects.memberof -split "CN=" | % {($_ -split ",")[0]}
            }
            elseif ($csv) {
                # output to CSV
                Write-Host -ForegroundColor Green "File saved to $OutputFile"
                $ADObjects | Export-Csv $OutputFile -NoTypeInformation
            }
            else {
                Return $ADObjects 
            }
        } 
    } 
     
    End{} 
} 
