# ============================================================
# OneState RP Mod - Daily Auto-Update Script
# Runs python update.py and captures output to update-log.txt
# Run via Windows Task Scheduler (daily)
# ============================================================

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile     = Join-Path $ScriptDir "update-log.txt"

function Write-Log($msg) {
    $ts = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $line = "[$ts] $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Write-Log "=== PowerShell Auto-Update Wrapper Started ==="

try {
    $PythonScript = Join-Path $ScriptDir "update.py"
    # Execute python update.py and stream output line by line to write-log
    & python "$PythonScript" 2>&1 | ForEach-Object {
        Write-Log $_.ToString()
    }
} catch {
    Write-Log "ERROR: Execution failed - $_"
    exit 1
}

Write-Log "=== PowerShell Auto-Update Wrapper Finished ==="
