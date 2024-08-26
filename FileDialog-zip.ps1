<#
    .DESCRIPTION
        Select files and extract zips if they are found

    .NOTES
        Created by Jason Svatos
        3/1/2019
#>
$outputdir = "$env:TEMP\zipfolder\"

function extractZip {
    param(
        [parameter(ValueFromPipeline=$true, mandatory=$true)]$zipfile
    )
    Add-Type -assembly “system.io.compression.filesystem”
    [io.compression.zipfile]::ExtractToDirectory($zipfile, $outputdir)

}

function fileDialog {
    param(
        [parameter(mandatory=$false)]$initialdir = [System.Environment]::GetFolderPath("Desktop")
    )
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect = $true # Multiple files can be chosen
	    Filter = 'All files (*.*)|*.*' # Specified file types
        InitialDirectory = $initialdir
        Title = "Select certificates"
    }
    [void]$FileBrowser.ShowDialog()
    
    $path = $FileBrowser.FileNames;
    $files = New-Object System.Collections.ArrayList
    #loop through list of selected files
    If($path -like "*\*") {
	    foreach($file in $path){
            if ([System.IO.Path]::GetExtension($file) -eq ".zip") {
                extractZip -zipfile $file
                fileDialog -initialdir $outputdir
                Remove-Item -Path $outputdir -Recurse
            }
            else {
                $files.Add($file) | Out-Null
            }
	    }
    }
    $files
}
