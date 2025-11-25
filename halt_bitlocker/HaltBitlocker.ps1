# Auto-elevate if not running as admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n[INFO] Script is not running as Administrator. Attempting to restart with elevated privileges..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2

    # Relaunch with elevation
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Confirm elevation
Write-Host "`n[INFO] Script is running as Administrator." -ForegroundColor Green

# Suspend BitLocker
Write-Host "`n[INFO] Suspending BitLocker on C: for one reboot..." -ForegroundColor Cyan
Suspend-BitLocker -MountPoint "C:" -RebootCount 1

# Confirm status
$bitlockerStatus = Get-BitLockerVolume -MountPoint "C:"
Write-Host "`n[INFO] BitLocker Status Summary:" -ForegroundColor Green
Write-Host "  Volume Status: $($bitlockerStatus.VolumeStatus)"
Write-Host "  Protection Status: $($bitlockerStatus.ProtectionStatus)"

# Ask user what to do next
Write-Host "`nWhat would you like to do now?" -ForegroundColor Yellow
Write-Host "1 = Shut down"
Write-Host "2 = Restart"
Write-Host "3 = Do nothing / exit script"
$choice = Read-Host "Enter your choice (1/2/3)"

switch ($choice) {
    "1" {
        Write-Host "`n[INFO] Shutting down the system..." -ForegroundColor Cyan
        Stop-Computer -Force
    }
    "2" {
        Write-Host "`n[INFO] Restarting the system..." -ForegroundColor Cyan
        Restart-Computer -Force
    }
    "3" {
        Write-Host "`n[INFO] Exiting without shutdown or restart." -ForegroundColor Green
        Exit
    }
    default {
        Write-Host "`n[WARNING] Invalid input. Defaulting to shutdown..." -ForegroundColor Red
        Start-Sleep -Seconds 2
        Stop-Computer -Force
    }
}
