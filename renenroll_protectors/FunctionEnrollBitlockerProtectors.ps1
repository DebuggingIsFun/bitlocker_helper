# ----------------------------------------------
# Reenroll BitLocker with new TPM and AD Recovery Key Sync
# Auto-elevate script if not running as Administrator (pwsh 7 requierd)
# ----------------------------------------------

# Elevation Check
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n[INFO] Script is not running as Administrator. Attempting to restart with elevated privileges..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2

    # Relaunch with elevation
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# -------------------------------
function ReenrollProtcector {
    Write-Host "`n[INFO] Starting BitLocker reenrollment process..." -ForegroundColor Cyan

    # Step 1: Get BitLocker volume info
    $bitlocker = Get-BitLockerVolume -MountPoint "C:"

    if ($null -eq $bitlocker) {
        Write-Host "[ERROR] Could not retrieve BitLocker info for C: drive." -ForegroundColor Red
        return
    }

    # Step 2: Suspend BitLocker temporarily
    Suspend-BitLocker -MountPoint "C:" -RebootCount 0
    Write-Host "[INFO] BitLocker protection suspended." -ForegroundColor Green

    # Step 3: Remove all existing key protectors
    $bitlocker.KeyProtector | ForEach-Object {
        Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $_.KeyProtectorId
    }
    Write-Host "[INFO] Old key protectors removed." -ForegroundColor Green

    # Step 4: Add new TPM protector
    Add-BitLockerKeyProtector -MountPoint "C:" -TpmProtector
    Write-Host "[INFO] New TPM protector added." -ForegroundColor Green

    # Step 5: Add new recovery password protector (and trigger sync to AD if GPO allows)
    $newRecoveryKey = Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
    Write-Host "[INFO] New recovery password protector added." -ForegroundColor Green
    Write-Host "        Recovery Key ID: $($newRecoveryKey.RecoveryPasswordProtector.RecoveryPasswordId)" -ForegroundColor DarkCyan

    # Step 6: Resume BitLocker protection
    Resume-BitLocker -MountPoint "C:"
    Write-Host "[INFO] BitLocker protection resumed." -ForegroundColor Green

    Write-Host "BitLocker reenrollment completed successfully." -ForegroundColor Cyan
}

# Run the function
ReenrollBitLocker
