function StreamReader {

    <#
        .SYNOPSIS
            Read text file(s) and parse them line-by-line using Stream Reader
            Much more memory-friendly and faster than Get-Content

        .NOTES
            Created By Jason Svatos
            Still working on this script - created 1/14/2016.
            -Pipeline input of arrays not working
            -Tail not working yet

        .DESCRIPTION
            Using StreamReader - you are using the .NET framework to read files
            This allows you to read files in text (-ReadToEnd) or line-by-line (default).
            This is also faster as Get-Content reads files into memory first. That is fine unless you have
            a large file which takes up too much memory - that's where this will come in handy.
            Using -ReadToEnd switch will make reading larger files 5x-10x faster.

        .EXAMPLE
            StreamReader -Files "c:\temp\text.txt" -Count
            Will read all lines of c:\temp\text.txt and return the amount of lines

        .EXAMPLE
            $files = @("c:\temp\test.txt", "c:\temp\two.txt")
            $files | StreamReader
            Will run through all lines in both files in the $files array

        .EXAMPLE
            StreamReader -Files "C:\Windows\SoftwareDistribution\ReportingEvents.log" -readToEnd
            This will read in the file ReportingEvents.log file for Windows Update. This will read the file to the end without
            going line-by-line. If you use measure command, you will notice it reads much faster than get-content
            Measure-Command -Expression {StreamReader -Files "C:\Windows\SoftwareDistribution\ReportingEvents.log" -readToEnd}
            vs
            Measure-Command -Expression {Get-Content "C:\Windows\SoftwareDistribution\ReportingEvents.log"}

        .PARAMETER Files
            [Mandatory] String or Array - Path to text file(s) to process for this command.

        .PARAMETER List
            [SWITCH] Default Selection, is not necessary to declare.
            Use to list the contents of the file(s) input from $Files without doing anything to them.
            This will read the file(s) line-by-line and return each line separately.

        .PARAMETER Count
            [SWITCH] Use to only return the amount of lines in the file(s)

        .PARAMETER ReadToEnd
            [SWITCH] Use to read the files to the end without parsing Line-By-Line.

        .PARAMETER Tail
            [INT] Read # amount of lines from end of file
            Does not work yet

        .PARAMETER Head
            [INT] Read # amount of lines from top of file

        .PARAMETER SkipLines
            [INT] Skip # amount of lines from top of file
            This will only work with Head, List, and Count
    #>


    # create parameters
    [CmdletBinding(DefaultParameterSetName=”List")]
    param ( 
        [parameter( Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=0,
                    HelpMessage="String/Array - Files(s) to read information from")]
        [string[]]$Files,
        
        [parameter( Mandatory=$false,
                    HelpMessage="SWITCH - Use to just list the content of the files - Default",
                    ParameterSetName="List")]
        [switch]$List,

        [parameter( Mandatory=$false,
                    HelpMessage="SWITCH - Use to count total lines in file(s)",
                    ParameterSetName="Count")]
        [switch]$Count,

        [parameter( Mandatory=$false,
                    HelpMessage="Read file to end without going line-by-line - faster",
                    ParameterSetName="ReadToEnd")]
        [switch]$ReadToEnd,

        [parameter( Mandatory=$false,
                    HelpMessage="Show last ## of lines of file, such as tail for Get-Content",
                    ParameterSetName="Tail")]
        [int]$Tail,

        [parameter( Mandatory=$false,
                    HelpMessage="Show first ## of line of file, such as head for Get-Content",
                    ParameterSetName="Head")]
        [int]$Head,

        [parameter( Mandatory=$false,
                    HelpMessage="Skip # amount of lines at the top of the file, Only works with Head, List, and Count")]
        [int]$SkipLines
    )

    Begin {
        # Set all errors to stop processing
        $ErrorActionPreference = "Stop"    
        # set linecount to 0 for amount of lines
        [int]$lineCount = 0
        # set current line for each file - used to keep track of Head and Tail
        [int]$currLine = 0
    }

    Process {        
        # Loop through files
        foreach ($file in $Files)
        {
            # reset current line for each file to 0
            $currLine = 0
            # keep track of $skipLines for each file
            if ($SkipLines)
            {                
                # this gets set to false on each file if the line count is meant for skipping
                # reset to $true for each file so every file gets lines skipped
                [bool]$skip = $true
            }
            # check if the file exists first before doing anything
            if (-not [System.IO.File]::Exists($File))
            {
                # ERROR - File does not exist!
                Write-Error "$File does not exist or cannot be accessed"
            }

            try {                
                # this is to open files in a read/write mode without locking them
                # Required if you want to view files like Get-Content does
                # StreamReader will normally automatically lock files while it is reading them, which causes problems 
                #   for open files and system files
                $readFile = [System.IO.File]::Open($File, 'Open', 'Read', 'ReadWrite')                
                # create new stream reader object
                $streamReader = New-Object System.IO.StreamReader($readFile)
            }
            catch {
                # Error creating StreamReader
                Write-Host "Error Creating StreamReader object"
                if ($streamReader -ne $null)
                {
                    # close the stream that is open on the file
                    $streamReader.Dispose()
                }
                throw $_
            }

            # Check if user wants to use Tail - or show just a number of last lines in code
            # Will need to read to end of file, then count backwards to list correctly
            if ($Tail)
            {
                try {
                    # Read to end
                    $streamReader.ReadToEnd()
                }
                catch {
                    # error using tail parameter
                    Write-Output $_.Exception.Message.ToString()
                }
            }

            # check if user wants to read file as one large string instead of line-by-line
            if ($ReadToEnd)
            {
                try {
                    $streamReader.ReadToEnd()
                }
                catch {
                    # Error reading to end of file
                    Write-Output $_.Exception.Message.ToString()
                }
            }

            # read file line-by-line
            else {
                try {
                    # Read the first line of the file
                    $line = $streamReader.ReadLine()
                }
                catch {
                    # error reading first line
                    Write-Host "Error reading first line."
                    Write-Output $_.Exception.Message.ToString()
                }
        
                try {
                    # Loop through the file until it has ended
                    while ($line -ne $null)
                    {
                        # check if user wants to skip lines at the beginning of the file
                        # Keep before $lineCount and $currLine so it doesn't count those lines in the totals
                        if ($skip)
                        {                            
                            if ($SkipLines -eq $currLine)
                            {
                                # if skip line is met, reset current line
                                $currLine = 0
                                # Set to false to prevent skipping other lines as well
                                $skip = $false
                            }
                            else
                            {
                                # read the current line
                                $line = $streamReader.ReadLine()
                                # increment current line
                                $currLine += 1
                                # go to next line without displaying
                                Continue
                            }
                        }

                        # increment the amount of lines by 1
                        $lineCount += 1
                        # increment the current file's line by 1
                        $currLine += 1
                        # check if $Count is used
                        # if it is, skip displaying lines                    
                        if (-not $Count)
                        {
                            # print the current line
                            Write-Output $line
                        }

                        # check if Head is used
                        # only print that many lines
                        if ($Head)
                        {
                            # stop processing lines if $Head is reached
                            if ($Head -eq $currLine)
                            {
                                # break out of while-loop
                                break
                            }
                        }

                        # read new line
                        $line = $streamReader.ReadLine()                    
                    }
                    # close the current file in the stream reader                    
                    $streamReader.Dispose()
                }
                catch {
                    Write-Host "Error looping through the file(s)."
                    Write-Output $_.Exception.Message.ToString()
                }
            }
        }
    }

    End {
        # print line count if requested
        if ($Count)
        {
            Write-Host $lineCount
        }
        # close the stream
        if ($streamReader -ne $null)
        {
            # disposing of the stream
            $streamReader.Dispose()
        }
    }
}
