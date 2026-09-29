@echo off
setlocal

set "INSTALL=C:\MKLinkTool"
set "PS1=%INSTALL%\MKLinkTool.ps1"

echo ============================================
echo       MKLink Copy / Paste Installer
echo ============================================
echo.

if not exist "%INSTALL%" mkdir "%INSTALL%"

echo Creating PowerShell script...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$script = @'
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("copy", "paste")]
    [string]$Action,

    [string]$Path,

    [switch]$Elevated
)

$StateFile = Join-Path $env:TEMP "MKLinkState.txt"


# ============================================================
# MKLINK COPY
# ============================================================

if ($Action -eq "copy") {

    Add-Type -AssemblyName System.Windows.Forms

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {

        [System.Windows.Forms.MessageBox]::Show(
            "Please select a file.",
            "MKLink Copy",
            "OK",
            "Error"
        )

        exit 1
    }

    $Source = (Get-Item -LiteralPath $Path).FullName

    Set-Content `
        -LiteralPath $StateFile `
        -Value @(
            "SOURCE=$Source"
            "DESTINATION="
        ) `
        -Encoding UTF8

    exit 0
}


# ============================================================
# MKLINK PASTE
# ============================================================

if ($Action -eq "paste") {

    Add-Type -AssemblyName System.Windows.Forms

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    $IsAdmin = $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )


    # --------------------------------------------------------
    # Normal process: save destination, then elevate
    # --------------------------------------------------------

    if (-not $IsAdmin) {

        if (-not (Test-Path -LiteralPath $StateFile)) {

            [System.Windows.Forms.MessageBox]::Show(
                "No file has been selected with MKLink Copy.",
                "MKLink Paste",
                "OK",
                "Warning"
            )

            exit 1
        }


        $Lines = Get-Content `
            -LiteralPath $StateFile `
            -Encoding UTF8


        $SourceLine = $Lines |
            Where-Object { $_ -like "SOURCE=*" } |
            Select-Object -First 1


        if (-not $SourceLine) {

            [System.Windows.Forms.MessageBox]::Show(
                "No source file was found.",
                "MKLink Paste",
                "OK",
                "Error"
            )

            exit 1
        }


        $Source = $SourceLine.Substring(7)

        $DestinationFolder = $Path


        # Save both paths before UAC
        Set-Content `
            -LiteralPath $StateFile `
            -Value @(
                "SOURCE=$Source"
                "DESTINATION=$DestinationFolder"
            ) `
            -Encoding UTF8


        # Start elevated copy of ourselves
        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile"
                "-ExecutionPolicy"
                "Bypass"
                "-File"
                "`"$PSCommandPath`""
                "paste"
                "-Elevated"
            )

        exit 0
    }


    # ========================================================
    # ADMINISTRATOR PROCESS
    # ========================================================

    if (-not (Test-Path -LiteralPath $StateFile)) {

        [System.Windows.Forms.MessageBox]::Show(
            "MKLink state information was not found.",
            "MKLink Paste",
            "OK",
            "Error"
        )

        exit 1
    }


    $Lines = Get-Content `
        -LiteralPath $StateFile `
        -Encoding UTF8


    $SourceLine = $Lines |
        Where-Object { $_ -like "SOURCE=*" } |
        Select-Object -First 1


    $DestinationLine = $Lines |
        Where-Object { $_ -like "DESTINATION=*" } |
        Select-Object -First 1


    if (-not $SourceLine) {

        [System.Windows.Forms.MessageBox]::Show(
            "Source file was not found.",
            "MKLink Paste",
            "OK",
            "Error"
        )

        exit 1
    }


    if (-not $DestinationLine) {

        [System.Windows.Forms.MessageBox]::Show(
            "Destination folder was not supplied.",
            "MKLink Paste",
            "OK",
            "Error"
        )

        exit 1
    }


    $Source = $SourceLine.Substring(7)

    $DestinationFolder = $DestinationLine.Substring(12)


    $Source = $Source.Trim('"')

    $DestinationFolder = $DestinationFolder.Trim('"')


    # --------------------------------------------------------
    # Verify source
    # --------------------------------------------------------

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {

        [System.Windows.Forms.MessageBox]::Show(
            "Source file does not exist:`n`n$Source",
            "MKLink Paste",
            "OK",
            "Error"
        )

        exit 1
    }


    # --------------------------------------------------------
    # Verify destination
    # --------------------------------------------------------

    if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {

        [System.Windows.Forms.MessageBox]::Show(
            "Destination folder does not exist:`n`n$DestinationFolder",
            "MKLink Paste",
            "OK",
            "Error"
        )

        exit 1
    }


    # --------------------------------------------------------
    # Create destination filename
    # --------------------------------------------------------

    $FileName = [System.IO.Path]::GetFileName($Source)

    $Destination = Join-Path `
        $DestinationFolder `
        $FileName


    # --------------------------------------------------------
    # Don't overwrite existing file
    # --------------------------------------------------------

    if (Test-Path -LiteralPath $Destination) {

        [System.Windows.Forms.MessageBox]::Show(
            "A file or link already exists:`n`n$Destination",
            "MKLink Paste",
            "OK",
            "Warning"
        )

        exit 1
    }


    # --------------------------------------------------------
    # Create symbolic link
    # --------------------------------------------------------

    try {

        New-Item `
            -ItemType SymbolicLink `
            -Path $Destination `
            -Target $Source `
            -ErrorAction Stop |
            Out-Null


        [System.Windows.Forms.MessageBox]::Show(
            "MKLink created successfully!`n`nSource:`n$Source`n`nLink:`n$Destination",
            "MKLink Paste",
            "OK",
            "Information"
        )


        Remove-Item `
            -LiteralPath $StateFile `
            -Force `
            -ErrorAction SilentlyContinue
    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Could not create the symbolic link.`n`n$($_.Exception.Message)",
            "MKLink Paste",
            "OK",
            "Error"
        )
    }
}
'@

Set-Content -Path 'C:\MKLinkTool\MKLinkTool.ps1' -Value $script -Encoding UTF8"

if errorlevel 1 (
    echo.
    echo ERROR: Could not create PowerShell script.
    pause
    exit /b 1
)

echo Creating Registry entries...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$base='HKCU:\Software\Classes';

$copy='HKCU:\Software\Classes\*\shell\MKLinkCopy';
New-Item -Path $copy -Force | Out-Null;
Set-ItemProperty -Path $copy -Name '(Default)' -Value 'MKLink Copy';
Set-ItemProperty -Path $copy -Name 'Icon' -Value 'shell32.dll,29';

$copyCmd=$copy+'\command';
New-Item -Path $copyCmd -Force | Out-Null;
Set-ItemProperty -Path $copyCmd -Name '(Default)' -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\MKLinkTool\MKLinkTool.ps1\" copy \"%%1\"';

$paste='HKCU:\Software\Classes\Directory\Background\shell\MKLinkPaste';
New-Item -Path $paste -Force | Out-Null;
Set-ItemProperty -Path $paste -Name '(Default)' -Value 'MKLink Paste';
Set-ItemProperty -Path $paste -Name 'Icon' -Value 'shell32.dll,3';

$pasteCmd=$paste+'\command';
New-Item -Path $pasteCmd -Force | Out-Null;
Set-ItemProperty -Path $pasteCmd -Name '(Default)' -Value 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\MKLinkTool\MKLinkTool.ps1\" paste \"%%V\"'"

if errorlevel 1 (
    echo.
    echo ERROR: Could not install Registry entries.
    pause
    exit /b 1
)

echo.
echo Restarting Windows Explorer...

taskkill /F /IM explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul
start explorer.exe

echo.
echo ============================================
echo          Installation Complete!
echo ============================================
echo.
echo Installed:
echo     C:\MKLinkTool\MKLinkTool.ps1
echo.
echo Usage:
echo.
echo 1. Right-click a file
echo    -> MKLink Copy
echo.
echo 2. Open destination folder
echo    -> Right-click empty space
echo    -> MKLink Paste
echo.
echo 3. Click YES when Windows asks
echo    for Administrator permission.
echo.
echo ============================================
echo.

pause
