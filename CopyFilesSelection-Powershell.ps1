#Created By Jason Svatos
#Created 5-30-2015
#Added PS 1/2 Reflection.Assembly loadwithpartialname 6-4-2015

#Check version of Powershell
if (($PSVersionTable.PSVersion).Major -lt "3")
{ # If powershell 1 / 2, use Reflection.Assembly to load System.Windows.Forms
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
}
else 
{ # If powershell 3+, use Add-Type to load System.Windows.Forms
    Add-Type -AssemblyName System.Windows.Forms
}


function Get-FilePath {
    #Get File Path function
    $fileSelect = New-Object System.Windows.Forms.OpenFileDialog #create new OpenFileDialog object
    $fileSelect.Filter = "All Files (*.*)| *.*" #filter is set for all files
    $fileSelect.Title = "Choose a file to copy"
    [void]$fileSelect.ShowDialog() #Show file selection dialog box and void output
    $copyFile = $fileSelect.FileName #get selected file path

    #Save File Path
    $fileSave = New-Object System.Windows.Forms.OpenFileDialog #create new OpenFileDialog object
    $fileSave.Filter = "All Files (*.*)| *.*" #filter is set for all files
    $fileSave.Title = "Choose where to save copied file"
    [void]$fileSave.ShowDialog() #Show file selection dialog box and void output
    $saveFile = $fileSave.FileName
}

function Get-FolderPath {
      
    #Get Folder Path function
    $folderSelect = New-Object System.Windows.Forms.FolderBrowserDialog #Create new FolderBrowserDialog
    $folderSelect.ShowNewFolderButton = $false #Hide "make new folder" button
    $folderSelect.Description = "Choose a folder to copy"
    #$folderSelect.RootFolder = "MyDocuments"
    [void]$folderSelect.ShowDialog() #Show folder dialog and void output
	#[Windows.Forms.MessageBox]::Show("hello");
    $copyFolder = $folderSelect.SelectedPath #Get selected folder path

    #Save File Path
    $folderSave = New-Object System.Windows.Forms.FolderBrowserDialog #Create new FolderBrowserDialog
    $folderSave.ShowNewFolderButton = $true
    $folderSave.Description = "Choose a location to save the copied folder to"
    #$folderSave.RootFolder = "MyDocuments"    
    [void]$folderSave.ShowDialog() #Show folder dialog and void output
    $saveFolder = $folderSave.SelectedPath #Get selected folder path
    
    #Check if both $copyFolder and $saveFolder have data - if not, show message and program will close
    #else - Start copy process
    if ([System.String]::IsNullOrEmpty($copyFolder) -or [System.String]::IsNullOrEmpty($saveFolder)) 
    {
        [System.Windows.Forms.MessageBox]::Show("Path cannot be empty.")                
    }
    else {
        try {
            #Start-Process -FilePath powershell.exe -ArgumentList "-nologo -noprofile -command Robocopy.exe $copyFolder $saveFolder /E /XO /R:1 /W:1 /FFT /LOG+:c:\temp\CopyFilesSelection.txt" #for NTFS to non-NTFS
            Robocopy.exe $copyFolder $saveFolder /E /XO /R:1 /W:1 /FFT /TEE /LOG+:c:\temp\CopyFilesSelection.txt
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.ToString())
        }
    }
}

Get-FolderPath
