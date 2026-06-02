# ============================================================
# OneState RP Mod - Daily Auto-Update Script
# Scrapes getmodsapk.com and updates index.html automatically
# Run via Windows Task Scheduler (daily)
# ============================================================

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$IndexFile   = Join-Path $ScriptDir "index.html"
$LogFile     = Join-Path $ScriptDir "update-log.txt"
$SourceUrl   = "https://getmodsapk.com/one-state-rp-mod-apk/"

function Write-Log($msg) {
    $ts = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $line = "[$ts] $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Write-Log "=== OneState RP Mod Auto-Update Started ==="

# ── 1. Download the source page ─────────────────────────────
try {
    $response = Invoke-WebRequest -Uri $SourceUrl -UseBasicParsing -TimeoutSec 30
    $html = $response.Content
    Write-Log "Page downloaded successfully (${($html.Length)} bytes)"
} catch {
    Write-Log "ERROR: Failed to download page - $_"
    exit 1
}

# ── 2. Extract Version ───────────────────────────────────────
$versionMatch = [regex]::Match($html, '"softwareVersion"\s*:\s*"([^"]+)"')
if ($versionMatch.Success) {
    $version = $versionMatch.Groups[1].Value
    Write-Log "Version found: $version"
} else {
    # fallback: look for vX.X.X pattern in title
    $versionMatch2 = [regex]::Match($html, 'v(\d+\.\d+\.\d+)')
    $version = if ($versionMatch2.Success) { $versionMatch2.Value } else { "v1.0.3" }
    Write-Log "Version (fallback): $version"
}

# ── 3. Extract Description ───────────────────────────────────
$descMatch = [regex]::Match($html, '"description"\s*:\s*"([^"]+)"')
if ($descMatch.Success) {
    $description = $descMatch.Groups[1].Value
    Write-Log "Description found: $description"
} else {
    $description = "A life simulator where you are free to do whatever you like without any restriction. Welcome to the various maps and activities of one state rp mod apk with unlimited money and diamonds."
    Write-Log "Description (fallback used)"
}

# ── 4. Extract Thumbnail / Banner Image ─────────────────────
$thumbMatch = [regex]::Match($html, '"thumbnailUrl"\s*:\s*"([^"]+)"')
if ($thumbMatch.Success) {
    $rawThumb = $thumbMatch.Groups[1].Value
    # Make absolute if relative
    if ($rawThumb -notmatch '^https?://') {
        $thumbUrl = "https://getmodsapk.com$rawThumb"
    } else {
        $thumbUrl = $rawThumb
    }
    Write-Log "Thumbnail: $thumbUrl"
} else {
    $thumbUrl = "https://getmodsapk.com/storage/media/2025/12/onestate-rp-mod-apk.webp"
    Write-Log "Thumbnail (fallback)"
}

# ── 5. Extract Screenshots ───────────────────────────────────
$screenshotMatches = [regex]::Matches($html, 'data-src="(https://getmodsapk\.com/storage/media/[^"]+one-state[^"]+\.webp)"')
$screenshots = @()
foreach ($m in $screenshotMatches) {
    $url = $m.Groups[1].Value
    if ($screenshots -notcontains $url) {
        $screenshots += $url
    }
}
if ($screenshots.Count -eq 0) {
    # fallback known screenshots
    $screenshots = @(
        "https://getmodsapk.com/storage/media/2025/8/one-state-rp-mod-apk-2.webp",
        "https://getmodsapk.com/storage/media/2025/8/one-state-rp-mod-apk-1.webp",
        "https://getmodsapk.com/storage/media/2025/8/one-state-rp-mod-apk-3.webp"
    )
    Write-Log "Screenshots (fallback used)"
} else {
    Write-Log "Screenshots found: $($screenshots.Count)"
}

# ── 6. Extract Last Updated Date ────────────────────────────
$dateMatch = [regex]::Match($html, '"dateModified"\s*:\s*"(\d{4}-\d{2}-\d{2})')
if ($dateMatch.Success) {
    $rawDate = $dateMatch.Groups[1].Value
    $parsedDate = [datetime]::Parse($rawDate)
    $lastUpdated = $parsedDate.ToString("MMMM dd, yyyy")
    Write-Log "Last updated: $lastUpdated"
} else {
    $lastUpdated = (Get-Date).ToString("MMMM dd, yyyy")
    Write-Log "Last updated (today's date used)"
}

# ── 7. Extract File Size ─────────────────────────────────────
$sizeMatch = [regex]::Match($html, '"fileSize"\s*:\s*"([^"]+)"')
$fileSize = if ($sizeMatch.Success) { $sizeMatch.Groups[1].Value } else { "125 MB" }
Write-Log "File size: $fileSize"

# ── 8. Read existing index.html ─────────────────────────────
if (-not (Test-Path $IndexFile)) {
    Write-Log "ERROR: index.html not found at $IndexFile"
    exit 1
}
$content = Get-Content -Path $IndexFile -Raw
Write-Log "index.html loaded (${($content.Length)} bytes)"

# ── 9. Update Version Badge in Hero ─────────────────────────
$content = [regex]::Replace($content,
    'OFFICIAL ONESTATE APK v[\d\.]+',
    "OFFICIAL ONESTATE APK $version")

# Update version in hero title badge
$content = [regex]::Replace($content,
    'data-version="[^"]*"',
    "data-version=""$version""")

# ── 10. Update Gallery / Screenshot Images ──────────────────
# Find the gallery-grid block and replace all gallery-img src values
$screenshotBlock = ""
for ($i = 0; $i -lt $screenshots.Count; $i++) {
    $imgUrl = $screenshots[$i]
    $num = $i + 1
    $screenshotBlock += @"
                <div class="gallery-item reveal">
                    <img class="gallery-img" src="$imgUrl" alt="OneState RP Mod Screenshot $num" loading="lazy">
                    <div class="gallery-overlay"><span class="gallery-caption">Screenshot $num</span></div>
                </div>
`n
"@
}

$content = [regex]::Replace($content,
    '(?s)(<div class="gallery-grid">).*?(</div>\s*</section>)',
    "`$1`n$screenshotBlock            `$2",
    [System.Text.RegularExpressions.RegexOptions]::Singleline)

# ── 11. Update data attributes used by inline JS ────────────
# Patch a data block script tag we inject to pass live data to JS
$dataScript = @"
<script id="live-data" type="application/json">
{
  "version": "$version",
  "lastUpdated": "$lastUpdated",
  "fileSize": "$fileSize",
  "thumbnailUrl": "$thumbUrl",
  "description": "$description",
  "screenshots": [$(($screenshots | ForEach-Object { '"' + $_ + '"' }) -join ', ')]
}
</script>
"@

# Replace existing data block or append before </head>
if ($content -match '<script id="live-data"') {
    $content = [regex]::Replace($content,
        '(?s)<script id="live-data"[^>]*>.*?</script>',
        $dataScript,
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
} else {
    $content = $content -replace '</head>', "$dataScript`n</head>"
}

# ── 12. Update meta description ─────────────────────────────
$metaDesc = "Download One State RP Mod $version. $description"
if ($metaDesc.Length -gt 160) { $metaDesc = $metaDesc.Substring(0, 157) + "..." }
$content = [regex]::Replace($content,
    '(<meta name="description"\s+content=")[^"]*(")',
    "`${1}$metaDesc`${2}")

# ── 13. Write updated index.html ────────────────────────────
try {
    Set-Content -Path $IndexFile -Value $content -Encoding UTF8
    Write-Log "index.html updated successfully!"
} catch {
    Write-Log "ERROR: Failed to write index.html - $_"
    exit 1
}

Write-Log "=== Auto-Update Complete. Version: $version | Updated: $lastUpdated ==="
Write-Log ""
