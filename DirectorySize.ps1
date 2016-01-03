<#
    .SYNOPSIS
        Get folder sizes or last write time
        Can also change a number to human readable byte size (KB, MB, GB, etc)
        See help for each function on how to use them
        Jason Svatos
        2/2/2015

        Functions in this script:
        - LastWriteShortDate (Get last write time of a directory)
        - DirectorySize (Get size of a directory)
        - ConvertSizeHR (Convert a number to human readable byte size)
#>

################ Last Write Short Date ################

function LastWriteShortDate {
    <#
        .SYNOPSIS
            get short date for Last Write Time of a directory
            
        .EXAMPLE
          LastWriteShortDate -directory "c:\windows"
          Gets the short date form of the last time this folder was written to
    #>

    param (
        #Create directory parameter
        #Used to specify which directory/file to get data for
        [parameter(mandatory=$true)]$directory
    )

    [System.IO.Directory]::GetLastWriteTime($directory).ToShortDateString()
}

################ Directory Size ################

function DirectorySize {
    <#
        .SYNOPSIS
            get size of directory

        .PARAMETER folder
            String
            Folder to get the size of in a string: "c:\users\public"

        .PARAMETER recurse
            switch
            Whether or not you want to recurse through the whole folder for getting the size
            Default is disabled

        .PARAMETER hr
            Switch
            Output folder size in human readable form
            This option limits the use of the size in other applications/scripting purposes
            But it makes it easier to read for the user.
            Default is disabled

        .EXAMPLE
            DirectorySize -folder "c:\temp"
            Get the size of the c:\temp folder contents only
            Does not include sub folder sizes

        .EXAMPLE
            DirectorySize -folder "c:\temp" -recurse -hr
            Return the size of the c:\temp folder
            This will include the size of all sub folders as well
            Will return the size in human readable formt (MB, GB, etc)
    #>

    #Parameters
    [cmdletbinding()]
    param (
        #Folder to get size of
        [parameter(mandatory=$true,position=0)]$folder,
        #Use $true to recurse through all folders to get full size, default is $false
        [parameter(mandatory=$false,position=1)][switch]$recurse,
        #Use $true to output text in human readable form
        [parameter(mandatory=$false,position=2)][switch]$hr
    )

    Begin
    {
        # declare size variable as a long - to keep numbers correct
        [long]$size = 0
    }

    Process 
    {
        Out-File -InputObject $folder.FullName -FilePath c:\temp\00000000000aaa.txt -Append

        try {
            #Gets info for the specified directory        
            $directory = [System.IO.DirectoryInfo] $folder        
        }
        catch [System.UnauthorizedAccessException]
        {
            # catch any errors with accessing a directory
            Write-Host -ForegroundColor Red "Error accessing directory $folder, access is denied - Skipping"
            return 0
        }

        #get files/Directories and put in variable
        try {
            $files = $directory.GetFiles()
    
            #loop through files to get sizes
            foreach ($file in $files)
            {            
                $size += $file.length
            }
        }
        catch [System.UnauthorizedAccessException] 
        {
            Write-Host -ForegroundColor Red "Cannot access file: $Directory\$file, UnauthorizedAccessException"
        }
        catch {        
            Write-Host -ForegroundColor Red "Halting error on file: $Directory\$file, $($_.ToString())"
        }

        #if recurse switch not used, display console message
        if ($recurse -eq $false) {Write-Host -ForegroundColor Green "Skipping directories, Recurse is off, use '-recurse' for true folder size"}

        else
        {
            try {            
                #Get directories and put in variable
                $directories = $directory.GetDirectories()        
                #loop through directories to get sizes
                foreach ($d in $directories)
                {                    
                    Out-File -InputObject "$($d.FullName) : $size" -FilePath C:\temp\000000000Errors.ps1 -Append
                    #Call this function again - it keeps looping through all directories
                    $size += DirectorySize -folder $d -recurse                    
                }
            }
            catch [System.UnauthorizedAccessException] 
            {
                Write-Host -ForegroundColor Red "Cannot access directory: $d, UnauthorizedAccessException"
            }
            catch 
            {            
                Write-Host -ForegroundColor Red "Halting error on directory: $d, $($_.ToString())"
            }
        }
    } # end of process block

    End
    {        
        if ($hr) {ConvertSizeHR -number $size}
        else {return $size}
    }
    
}

################ Convert Size HR ################

function ConvertSizeHR {
        <#
            .SYNOPSIS
                Convert a number into file size format
                Rounds to nearest whole number, does not give decimal places

            .EXAMPLE
                ConvertSizeHR -number 1000
                Output will be 1 KB

            .EXAMPLE
                ConvertSizeHR -number 1234567890
                Output will be 1 GB
        #>

        param (
            [parameter(mandatory=$true)][long]$number
        )
        #get length of $size variable
        [int]$numlength = ($number.ToString()).Length
        #Set $hbyte to match size of $size variable
        #Set $size to KB, MB, GB, TB, or just keep bytes
        switch ($numlength)
        {
            #Round to 2 decimal places, Then divide by Byte size
            {4,5,6 -eq $_} {$hbyte = "KB"; $number = "{0:N2}" -f ($number / 1KB); break}
            {7,8,9 -eq $_} {$hbyte = "MB"; $number = "{0:N2}" -f ($number / 1MB); break}
            {10,11,12 -eq $_} {$hbyte = "GB"; $number = "{0:N2}" -f ($number / 1GB); break}
            {13,14,15 -eq $_} {$hbyte = "TB"; $number = "{0:N2}" -f ($number / 1TB); break}
            {16,17,18 -eq $_} {$hbyte = "PB"; $number = "{0:N2}" -f ($number / 1PB); break}
            Default {$hbyte = "Bytes"; break}
        }
        [string]$hsize = "$number $hbyte"
        #$shortsize = ($hsize.Substring(0,$firstcomma+3)).replace(",",".")
        return $hsize
    }
