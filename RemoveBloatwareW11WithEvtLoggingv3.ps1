# Remove Windows 11 Bloatware and also Learn about this picture ico on desktop for all users, with Windows Event Logging
# Ensure the script runs with elevated permissions
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    exit
}

Write-Host "Starting bloatware & Windows Spotlight removal process..." -ForegroundColor Green

# Register an Event Source (if not already present)
$EventSource = "IntuneBloatwareRemoval"
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    New-EventLog -LogName Application -Source $EventSource
}

# Log Start of Script Execution
Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1000 -Message "Starting bloatware & Windows Spotlight removal process."

# List of apps to remove
$BloatwareApps = @(
    "*Xbox*",
    "*LinkedIn*",
    "*Clipchamp*",
    "*Solitaire*",
    "*Weather*",
    "*News*",
    "*Paint3D*",
    "*MixedRealityPortal*",
    "*Skype*",
    "*People*",
    "*WindowsTips*"
)

# Remove provisioned packages (for new users)
Write-Host "Removing provisioned packages for new users..." -ForegroundColor Yellow
foreach ($App in $BloatwareApps) {
    try {
        Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like $App} | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1001 -Message "Provisioned package removed: $App"
    } catch {
        Write-EventLog -LogName Application -Source $EventSource -EntryType Error -EventId 1002 -Message "Error removing provisioned package: $App - $($_.Exception.Message)"
    }
}

# Remove installed packages (for existing users)
Write-Host "Removing installed packages for existing users..." -ForegroundColor Yellow
$Profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false }

foreach ($Profile in $Profiles) {
    if ($Profile.SID -and $Profile.LocalPath) {
        Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1009 -Message "Processing user profile: $($Profile.LocalPath) with SID: $($Profile.SID)"
        try {
            foreach ($App in $BloatwareApps) {
                $Packages = Get-AppxPackage -User $Profile.SID | Where-Object {$_.Name -like $App}
                foreach ($Package in $Packages) {
                    Remove-AppxPackage -Package $Package.PackageFullName -User $Profile.SID -ErrorAction SilentlyContinue
                    Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1003 -Message "Removed app for user $($Profile.LocalPath): $Package.PackageFullName"
                }
            }
            Write-Host "Removed apps for user: $($Profile.LocalPath)" -ForegroundColor Green
        } catch {
            Write-EventLog -LogName Application -Source $EventSource -EntryType Error -EventId 1004 -Message "Failed to remove apps for user: $($Profile.LocalPath) - $($_.Exception.Message)"
        }
    } else {
        Write-EventLog -LogName Application -Source $EventSource -EntryType Warning -EventId 1005 -Message "Skipping profile with invalid SID or path: $($Profile.LocalPath)"
    }
}

# Remove "Learn about this picture" Windows Spotlight icon
Write-Host "Removing 'Learn about this picture' desktop icon..." -ForegroundColor Yellow

$RegPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
)

foreach ($RegPath in $RegPaths) {
    if (Test-Path $RegPath) {
        try {
            Remove-Item -Path $RegPath -Recurse -ErrorAction SilentlyContinue
            New-ItemProperty -Path $RegPath -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -PropertyType DWORD -Value 1 -Force -ErrorAction SilentlyContinue
            Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1006 -Message "Removed Windows Spotlight registry: $RegPath"
        } catch {
            Write-EventLog -LogName Application -Source $EventSource -EntryType Error -EventId 1007 -Message "Failed to modify registry: $RegPath - $($_.Exception.Message)"
        }
    }
}

# Log completion
Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1008 -Message "Bloatware and Windows Spotlight removal completed successfully."

Write-Host "All specified apps and Windows Spotlight have been successfully removed!" -ForegroundColor Green