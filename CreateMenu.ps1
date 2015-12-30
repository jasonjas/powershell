<#
    .DESCRIPTION
        Useful functions which can be used in almost any fashion
        Powershell 2+ compatible
        Created 12/27/2015 by Jason Svatos
        jason@jasonsvatos.net

    .NOTES
        List of functions
        
        OutputError - Create error log and show on console
        CreateMenuList - List objects in a menu format
#>

########################## CREATE MENU LIST ##########################

function CreateMenuList {
    <#
        .SYNOPSIS
            Creates a text menu system which shows 30 items per screen
            Allows the user to move between the menus and choose the item
            Function returns only the selected result
            Will return -1 if an error occurs
            Will return 0 if user chooses to exit
            
        .DESCRIPTION
            Create a list to choose from and return the result
            Get objects via pipeline or manual input
            Maximum of 30 items listed at a time
            Will separate into different menus automatically
            Can move between menus with "n" and "p"
            Verifies input is correct or else it will keep displaying the menu

        .EXAMPLE
            $arrayOfObjects = "corn","wheat","soy"
            $arrayOfObjects | CreateMenuList

            List items as they are in the array.            
            Creates a list that looks like this:

            1. corn
            2. wheat
            3. soy
            There are 3 items on 1 menus.
            You are on menu # 1.
            Which menu item? (1-3): 

        .EXAMPLE
            $arrayOfObjects = "corn","wheat","soy"
            $arrayOfObjects | CreateMenuList -sort            
            List items in alphabetical order (ascending) with -sort parameter
            Creates a list that looks like this:

            1. corn
            2. soy
            3. wheat
            There are 3 items on 1 menus.
            You are on menu # 1.
            Which menu item? (1-3):            

        .EXAMPLE
            Get-Process | CreateMenuList -diplayProperty Name

            Will show the process names in a list on multiple menus

        .EXAMPLE
            Get-ChildItem c:\ | CreateMenuList
            List directory items            

        .EXAMPLE
            Get-Content c:\file.txt | CreateMenuList
            List items from a text file - each line will be a choice            

        .EXAMPLE
            Get-Content c:\file.txt | CreateMenuList -sort
            Each line will be a choice in Ascending order            

        .EXAMPLE
            Import-CSV c:\files\file.csv | CreateMenuList -displayProperty Name
            List items from a CSV - can use displayProperty for the headers
            Imagine header names are "Name", "Comments", "Age", "user ID"
            Will list the names on each row of the CSV

        .EXAMPLE
            Import-CSV c:\files\file.csv | CreateMenuList -displayProperty "user ID" -sort
            Will list the user IDs on each row of the CSV in ascending order

        .PARAMETER Values
            Objects to list in the menu
            Maximum list is 30
            Accepts explicit input or pipeline input            
            
        .PARAMETER DisplayProperty
            The property of the Values to display on the menu(s)
            Not mandatory, but it makes it easier for reading objects from piped commands
            Not every input will have a DisplayProperty (Example - from Get-Content or manual inputs)
            Common command Properties: Name, DisplayName
            Get-Process | CreateMenuList
            This will show the processes in the list but they will start with System.Diagnostics.Process
            1. System.Diagnostics.Process (concentr)
            2. System.Diagnostics.Process (conhost)
            3. System.Diagnostics.Process (conhost)
            4. System.Diagnostics.Process (csrss)
            
            Get-Process | CreateMenuList -displayProperty Name
            This will show the processes in the list by name - easier to read
            1. concentr
            2. conhost
            3. conhost
            4. csrss
            
        .PARAMETER Sort
            Sort items in list in ascending order
            
        .Parameter DisplayColor
            Display color of the write-host -ForegroundColor parameter.
            This is only used for showing which menu number you are on
            and how many menus exist
            
        .INPUTS
            [object[]] - You can input almost anything from a command or manual entry. However, it must contain text readable by the console.
            
        .OUTPUTS
            [object] - Object that has been chosen from the list in the type it was added in                        
    #>

    # declare parameters
    [cmdletbinding()]
    param (
            # Values
            # Create Aliases so ValueFromPipelineByPropertyName will show items properly            
            [parameter( Mandatory=$true,
                        ValueFromPipeline=$True,
                        ValueFromPipelineByPropertyName=$true,
                        HelpMessage="Array of objects to list in menu")]
            [Alias('Name','DisplayName','ComputerName','IPAddress','CN','__Server')]
            #[string[]]$Values,
            [object[]]$Values,
            
            # Property of Values to display on menu
            [parameter( Mandatory=$false,
                        HelpMessage="Property to display on the menu, Ex. 'Name'.")]
            [string]$displayProperty,                        

            # Sort - for sorting items ascending
            [parameter( Mandatory=$false,
                        HelpMessage="Sort objects in ascending order")]
            [switch]$sort,
            
            # Information display color for number of menus and the current menu
            # Used in case you can't see yellow on the screen
            [parameter( Mandatory=$false,
                        HelpMessage="Write-Host output color for number of menus")]
            [ValidateSet("Black","Blue","Cyan","DarkBlue","DarkCyan","DarkGray","DarkGreen","DarkMagenta","DarkRed","DarkYellow","Gray","Green","Magenta","Red","White","Yellow")]
            [string]$displayColor = "Yellow"
    )
    
    Begin {
        # log file location for errors
        [string]$logFile = "$env:LOCALAPPDATA\CreateMenuList-ErrorLog.txt"
        # Create counter for to number of Values
        $valuesCount = 0
        # counter for current objects in list
        $counter = 0
        # Create empty array for storing each menu item into
        [string[]]$inputObjects
    }

    Process {
        # Increment valuesCount by 1 to keep track of the amount of Values
        $valuesCount += 1

        # Need to add each $value into $inputObjects
        # This is required for when getting the arrays from pipeline input
        # if we don't do this, the last object from the pipeline will be the only one displayed
        $inputObjects += $Values
    }

    End {

        # Sort objects in ascending order if $sort switch is used
        if ($sort)
        {
            $inputObjects = $inputObjects | Sort
        }

            # do - until loop
            # Show menu and ask for which item to choose
            # Loop through it each time if item within list range is not selected
            # If no number is implied, it will keep showing the different menus after each input            

            do {                
                try {            
                    # clear screen - reduces clutter with multiple menus
                    clear                    

                    # get highest limit of $counter to be
                    # Keeps from having blank numbers if 15 items but have 30 per menu
                    if (($counter + 30) -gt $valuesCount)
                    {
                        # set high number to $valuesCount
                        $highCount = $valuesCount
                    }
                    else
                    {
                        # else, set high count to $counter + 30
                        $highCount = $counter + 30
                    }

                    # set counter to 1 if it's 0
                    # used to make the list numbers match up properly
                    #if ($counter -eq 0) {$counter++}

                    for ($counter; $counter -lt $highCount; $counter++)
                    {
                        # Write Number. Item to console
                        # Example 1. Apple, 2. Orange, etc
                        if (-not ([String]::IsNullOrEmpty($displayProperty)))
                        {
                            Write-Host ("{0}. {1}" -f $($counter + 1), $inputObjects[$counter].$displayProperty)
                        }
                        else
                        {
                            Write-Host ("{0}. {1}" -f $($counter + 1), $inputObjects[$counter])
                        }
                        # get menu number - sets to higher number if above the main digit
                        # Example 1.03 = 2, 2.6 = 3                
                    }
                    
                    # get menu we are in right now                    
                    $menuCount = [math]::Ceiling($counter / 30)           
                }
    
                catch {
                    # catch any errors from looping through input objects
                    "Error looping through input objects" | OutputError -logFile $logFile -Append
                    $_.Exception.Message.ToString() | OutputError -logFile $logFile -Append
                    Read-Host "Exiting script"
                    return -1
                }

                try {            
                    # Ask for which menu object to select
                    # create spacer
                    Write-Host ""

                    # show how many items and menus there are
                    Write-Host -ForegroundColor $displayColor -Object "There are $valuesCount items on $([Math]::Ceiling($valuesCount / 30)) menus."
                    # show which menu user is on
                    Write-Host -ForegroundColor $displayColor -Object "You are on menu # $menuCount."
                    # show how to exit menu
                    Write-Host -ForegroundColor $displayColor -Object "type EXIT to quit."
                    # create spacer
                    Write-Host ""

                    # get input from user in string format
                    [string]$selectMenuItem = Read-Host "Which menu item? (1-$valuesCount)"
                    
                    # check if user typed EXIT - return if user did
                    if ($selectMenuItem -ieq "exit")
                    {
                        # exit menu with 0
                        return 0
                    }
                    # case insensitive match for previous menu
                    elseif ($selectMenuItem -ieq "p")
                    {                        
                        # if currently on 1st menu, set counter to 0 to reset
                        # don't want to go negative
                        if ($menuCount -eq 1)
                        {
                            $counter = 0                            
                        }
                        else 
                        {
                            # get menu item, multiply by 30 to get the maximum number of results on it
                            # Subtract by 60 to get previous menu starting number (we start at last item on the previous menu)                            
                            # if this is the second menu (2), it will be 0 (2*30 = 60 - 60 = 0)
                            # if this is the fourth menu (4), it will be 60 (4*30 = 120 - 60 = 60)
                            $counter = ($menuCount * 30) - 60                            
                        }
                        # go to top of loop
                        continue
                    }

                    # case insensitive match for next menu
                    elseif ($selectMenuItem -ieq "n")
                    {                        
                        # check if we are on the last menu
                        if ($menuCount -eq ([math]::Ceiling($valuesCount / 30)))
                        {
                            # set $counter to number of last item on the previous menu
                            # Example 75 items, [Math]::Floor(75 / 30) = 2 * 30 = 60
                            $counter = [Math]::Floor($valuesCount / 30) * 30
                        }
                        else
                        {
                            # go to next menu
                            # Counter is already setup to continue to next menu
                            # so there is nothing we need to change for it
                        }
                        # go to top of loop
                        continue
                    }
   
                    # verify choice is between 1 and valuesCount
                    elseif (($selectMenuItem -ge 1) -and ($selectMenuItem -le $valuesCount))
                    {                        
                        # break do-while loop
                        break                        
                    }

                    else
                    {                        
                        Read-Host "$selectMenuItem is not a valid choice. Go back to menu # 1"
                        # show first menu
                        $counter = 0
                        # go to top of loop
                        continue
                    }
                }
                catch {
                    # catch any errors from selecting the menu item
                    "Error selecting menu item" | OutputError -logFile $logFile -Append
                    $_.TargetObject
                    $_.ScriptStackTrace
                    $_.FullyQualifiedErrorID
                    $_.ToString() | OutputError -logFile $logFile -Append
                    Read-Host "Exiting script"
                    return -1
                }
            } # end do
            # do - until item selected is between 1 and amount of items in list
            Until (($selectMenuItem -ge 1) -and ($selectMenuItem -le $valuesCount))       
                
        try {    
            # return the menu object string that was chosen            
            return $inputObjects[$selectMenuItem - 1]
        }
        catch {
            # Catch any errors from returning the chosen item from the array
            "Error extracting item after choosing it." | OutputError -logFile $logFile -Append
            $_.TargetObject
            $_.ScriptStackTrace
            $_.FullyQualifiedErrorID
            $_.Exception.Message.ToString() | OutputError -logFile $logFile -Append
            Read-Host "Exiting script"
            return -1
        }
    }
}

########################## OUTPUT ERROR ##########################

function OutputError {
    <#
        .SYNOPSIS
            Get an error from try/catch
            Output error to log and show error on console
            Like Tee-Object, but Tee-Object in Powershell 2 does not contain -Append

        .EXAMPLE
            $_.Exception.Message.ToString() | OutputError -logFile "$ENV:LocalAppData\ErrorLog.txt" -Append
            This will take the error message string and append it to the %localappdata%\ErrorLog.txt file

        .PARAMETER Append
            Append information to the log file

        .PARAMETER logFile
            Log file path to save string data to 
            
        .PARAMETER errorString
            String containing error code/data/information to print to console.
            Mandatory       
    #>    

    [CmdletBinding()]
    param (
            [parameter( Mandatory=$true,
                        ValueFromPipeline=$true,
                        HelpMessage="String containing error information")]
            [Alias('InputObject')]
            [ValidateNotNullOrEmpty()]
            [string]$errorString,

            [parameter( Mandatory=$false,
                        ValueFromPipeline=$false,
                        HelpMessage="String for location of log file.")]
            [Alias('FilePath')]
            [ValidateNotNullOrEmpty()]
            [string]$logFile,

            [parameter( Mandatory=$false,
                        ValueFromPipeline=$false,
                        HelpMessage="SWITCH - Append information to log file")]
            [switch]$Append
    )

    # check if $logfile has been used
    if ($logFile)
    {
        if ($Append)
        {
            # Output data to log file - Append
            $errorString | Out-File -FilePath $logFile -Append
        }
        else 
        {
            # Output data to log file - no append
            $errorString | Out-File -FilePath $logFile -Force
        }
    }

    # Return the error string to use with something else if needed
    return $errorString
}
