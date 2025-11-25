# ----------------------------------------------
# Reenroll BitLocker with new TPM and AD Recovery Key Sync
# Auto-elevate script if not running as Administrator  (pwsh 7 requierd)
# ----------------------------------------------

# Elevation Check
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[INFO] Script is not running as Administrator. Attempting to restart with elevated privileges..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2

    # Relaunch with elevation
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Reenroll BitLocker to a new TPM and regenerate recovery key

# Step 1: Get BitLocker info
$bitlocker = Get-BitLockerVolume -MountPoint "C:"

# Step 2: Suspend BitLocker temporarily (until reboot)
Suspend-BitLocker -MountPoint "C:" -RebootCount 0
Write-Host "BitLocker protection suspended."

# Step 3: Remove all existing key protectors
$bitlocker.KeyProtector | ForEach-Object {
    Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $_.KeyProtectorId
}
Write-Host "Old key protectors removed."

# Step 4: Add new TPM protector
Add-BitLockerKeyProtector -MountPoint "C:" -TpmProtector
Write-Host "New TPM protector added."

# Step 5: Add new recovery password protector (automatically syncs to AD if GPO is enabled)
$newRecoveryKey = Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
Write-Host "New recovery password protector added."
Write-Host "Recovery Key ID: $($newRecoveryKey.RecoveryPasswordProtector.RecoveryPasswordId)"

# Step 6: Resume BitLocker protection
Resume-BitLocker -MountPoint "C:"
Write-Host "BitLocker protection resumed."

# Done
Write-Host "BitLocker successfully reenrolled to new TPM and recovery key regenerated."
PAUSE