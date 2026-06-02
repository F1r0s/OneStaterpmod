# Run this script ONCE as Administrator to schedule the daily auto-update
# It will run auto-update.ps1 every day at 8:00 AM

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path $ScriptDir "auto-update.ps1"
$TaskName   = "OneStateRP-DailyUpdate"

# Remove existing task if present
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`""

$Trigger = New-ScheduledTaskTrigger -Daily -At "08:00AM"

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "OneState RP Mod - Daily sync of version, screenshots and description from getmodsapk.com" `
    -RunLevel Highest `
    -Force

Write-Host ""
Write-Host "✅ Scheduled task '$TaskName' created successfully!" -ForegroundColor Green
Write-Host "   Runs: Every day at 8:00 AM" -ForegroundColor Cyan
Write-Host "   Script: $ScriptPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run immediately: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
Write-Host "To remove:         Unregister-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
