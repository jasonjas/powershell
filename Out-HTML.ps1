<#
    .SYNOPSIS
        Create a decent looking HTML report page from objects and strings
        Header and CSS from: http://myrandomthoughts.co.uk/2016/01/out-fancyhtml-function/

    .DESCRIPTION
        Takes objects that are piped or declared and exports them to a HTML format where they can be viewed.
        Creates a banner with information and lists everything in a table        

    .PARAMETER InputObject
        Value(s) that can be piped into the function or declared using the parameter.

    .PARAMETER SaveLocation
        The location to save the HTML report page to - use .html at the end for it to pull up in a browser automatically

    .PARAMETER Properties
        Properties you want to show on the report - Defaults to showing all properties of the value(s) input

    .PARAMETER CompanyName
        The name of the company to display on the banner - default is blank

    .PARAMETER ComputerName
        The name of the computer to display on the banner - default is the local hostname

    .PARAMETER ReportName
        Name of the report to show on the banner - default is blank

    .PARAMETER TableWidth
        Width of the page to show on the screen. Default is 100%. Use CSS width values for this to work properly (50%, 500px, etc)

    .PARAMETER CreateObject
        Use this switch when the InputObject is string-based. ConvertTo-HTML does not process strings correctly and only displays system information. 
        This parameter will turn the string(s) into objects and then output them in a single-column table.

    .EXAMPLE
        Get-ChildItem c:\Windows | Out-HTML -SaveLocation "c:\temp\HTML-Report.html" -Properties "Name","FullName"

        This will display the contents of C:\Windows on the report. The only properties shown will be Name and FullName

    .EXAMPLE
        Get-Process | Select-Object Handles, WS, CPU, ProcessName | Out-HTML -SaveLocation "D:\processes.html" -CompanyName "MY COMPANY" -ReportName "Running Processes"

        This will get processes on the local compuer and select only the Handles, Working Set (Memory), CPU, and processes name. 
        This will then generate a report with "My Company" and "Running Processes" at the top of the banner page.

    .EXAMPLE
        $names = @("John","Sam","Wendy","Ashley")
        Out-HTML -InputObject $names -CompanyName "New School" -ReportName "Current Students" -TableWidth 50% -SaveLocation "\\server\folder\StudentReport.html" -CreateObject
        
        This will show a report with 4 names listed on it on 50% of the webpage. The report will show the company name and the report name on the banner.

    .NOTES
        Created By Jason Svatos
        Date 1/31/2016

        IMPORTANT NOTE - Convertto-HTML (what this function uses) does not process string arrays correctly (Examples - Get-Content c:\temp; [string[]]$name = "joe","tim","eric"; etc)
        Use the -CreateObject switch to process them to output a single column table with the information

    .INPUTS
        Object arrays or String Arrays from variables or commands.

    .OUTPUTS
        HTML file
#>

function Out-HTML {

    [CmdletBinding()]
    param (
        [parameter( Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true)]        
        [object[]]$InputObject,

        [parameter( Mandatory=$true)]
        [string]$SaveLocation,

        [parameter( Mandatory=$false,
                    HelpMessage="Properties you want to display on the HTML report. Leave this blank to default to all of them.")]
        [string[]]$Properties,

        [parameter( Mandatory=$false,
                    HelpMessage="Name of company to display on HTML page, default is blank")]
        [string]$CompanyName = "",

        [parameter( Mandatory=$false,
                    HelpMessage="Computer name the report is run on - defaults to computer it is run on.")]
        [string]$ComputerName = $env:COMPUTERNAME,

        [parameter( Mandatory=$false,
                    HelpMessage="Report Name to display on page, default is blank")]
        [string]$ReportName = "",

        [parameter( Mandatory=$false,
                    HelpMessage="Width of table to show on the screen, default is 100%")]
        [string]$TableWidth = "100%",

        [parameter( Mandatory=$false,
                    HelpMessage="Use this switch to process the InputObject as a string array, instead of as an object.")]
        [switch]$CreateObject
    )

    begin {
        
        # Declare static variables
        $userName = $env:USERNAME        
        $date = Get-Date -UFormat %D        
        
        # Header information - CSS
        # Keep the $TableWidth variable only on the HTML body tag - this will force everything else to be that size specifically and line up correctly
        $head = @"
        <style>
            html body       { font-family: Verdana, Geneva, sans-serif; font-size: 12px; height: 100%; margin: 0; overflow: auto; width: $TableWidth;}
            #header         { background: #0066a1; color: #ffffff;}
            #headerTop      { padding: 10px; }
            .logo1          { float: left;  font-size: 25px; font-weight: bold; padding: 0 7px 0 0; }
            .logo2          { float: left;  font-size: 25px; }
            .logo3          { float: right; font-size: 12px; text-align: right; }
            .headerRow1     { background: #66a3c7; height: 5px;}
            .serverRow      { background: #000000; color: #ffffff; font-size: 32px; padding: 10px; text-align: center; text-transform: uppercase;}
            .sectionRow     { background: #0066a1; color: #ffffff; font-size: 13px; padding: 1px 5px!important; font-weight: bold; height: 15px!important;}
            table           { background: #eaebec; border: #cccccc 1px solid; border-collapse: collapse; margin: 0; width: 100%; }
            table th        { background: #ededed; border-top: 1px solid #fafafa; border-bottom: 1px solid #e0e0e0; border-left: 1px solid #e0e0e0; height: 45px; min-width: 55px; padding: 0px 15px; text-transform: capitalize; }
            table tr        { text-align: center; }
            table td        { background: #fafafa; border-top: 1px solid #ffffff; border-bottom: 1px solid #e0e0e0; border-left: 1px solid #e0e0e0; height: 55px; min-width: 55px; padding: 0px 10px; }
            table td:first-child   { min-width: 175px; text-align: left; }
            table tr:last-child td { border-bottom: 0; }
            table tr:hover td      { background: #f2f2f2; }
            table tr:hover td.sectionRow { background: #0066a1; }
        </style>
"@

        # body HTML
        # Creates the banner at the top of the page                
        [string]$body = @"
        <div id="header"> 
            <div id="headerTop">
                <div class="logo1">$CompanyName</div>
                <div class="logo2">$ReportName</div>
                <div class="logo3">&nbsp;<br/>Generated by $userName on $date</div>
                <div style="clear:both;"></div>
            </div>
            <div style="clear:both;"></div>
        </div>
        <div class="headerRow1"></div>
        <div class="serverRow">$ComputerName</div>
        <div class="headerRow1"></div>
"@

    # create an object array to hold all the values in
    [object[]]$values
    }

    process {
        # this will take all the objects and put them into $values
        # the "Process" portion loops through each item in the $InputObject array automatically
        $values += $InputObject
    }

    end {
        # Check if $CreateObject is used
        # If so - this will convert the $values into an array of objects
        # This is needed for strings which do not process correctly with ConvertTo-HTML
        if ($CreateObject)
        {
            # declare a blank array
            $objectArray = @()
            Foreach ($val in $values) 
            {
                 $object = New-Object -TypeName PSObject
                 Add-Member -InputObject $object -Type NoteProperty -Name Value -Value $val
                 $objectArray += $object
            }

            # Export the objectArray to the chosen save location
            $objectArray | ConvertTo-Html -Body $body -Head $head -Property Value | Out-File $SaveLocation
        }

        else
        {
            # Export the values to the chosen save location
            $values | ConvertTo-Html -Body $body -Head $head | Out-File $SaveLocation
        }
    }
}
