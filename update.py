#!/usr/bin/env python3
"""
OneState RP Mod – Daily Auto-Update Script
Scrapes getmodsapk.com and updates index.html automatically.
Runs via GitHub Actions (daily cron).
"""

import re
import sys
import json
import datetime
import pathlib
import requests
from PIL import Image
import io

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR  = pathlib.Path(__file__).parent
INDEX_FILE  = SCRIPT_DIR / "index.html"
SOURCE_URL  = "https://getmodsapk.com/one-state-rp-mod-apk/"
IMAGES_DIR  = SCRIPT_DIR / "images"

# Ensure images directory exists
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

def log(msg: str):
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)

def download_and_convert_to_jpg(url: str, filename: str) -> str:
    """
    Downloads an image from url, converts it to JPG format,
    and saves it to the images/ folder.
    Returns the relative path to the image, e.g., 'images/filename.jpg'.
    """
    dest_path = IMAGES_DIR / f"{filename}.jpg"
    rel_path = f"images/{filename}.jpg"
    try:
        log(f"Downloading/converting image from {url}...")
        resp = requests.get(url, timeout=30, headers={"User-Agent": "Mozilla/5.0"})
        resp.raise_for_status()
        
        img = Image.open(io.BytesIO(resp.content))
        if img.mode != "RGB":
            img = img.convert("RGB")
            
        img.save(dest_path, "JPEG", quality=90)
        log(f"Saved and converted to: {rel_path}")
        return rel_path
    except Exception as e:
        log(f"WARNING: Failed to download/convert image {url} – {e}")
        if dest_path.exists():
            log(f"Using existing local file: {rel_path}")
            return rel_path
        return url

def ensure_static_images():
    """
    Ensures static site images (logo and background texture) are downloaded and local.
    """
    logo_url = "https://img.utdstc.com/icon/da3/dbf/da3dbf7ec14362e9f526f9294082e92e2d329fd08e5194a76841559975b77fd0:200"
    logo_path = IMAGES_DIR / "logo.jpg"
    if not logo_path.exists():
        download_and_convert_to_jpg(logo_url, "logo")
        
    bg_url = "https://i.ytimg.com/vi/FO831UlBB40/mqdefault.jpg"
    bg_path = IMAGES_DIR / "ambient-texture.jpg"
    if not bg_path.exists():
        download_and_convert_to_jpg(bg_url, "ambient-texture")


# ── 1. Download the source page ───────────────────────────────────────────────
log("=== OneState RP Mod Auto-Update Started ===")
try:
    resp = requests.get(SOURCE_URL, timeout=30,
                        headers={"User-Agent": "Mozilla/5.0"})
    resp.raise_for_status()
    html = resp.text
    log(f"Page downloaded successfully ({len(html)} bytes)")
except Exception as e:
    log(f"ERROR: Failed to download page – {e}")
    sys.exit(1)

# ── 2. Extract Version ────────────────────────────────────────────────────────
m = re.search(r'"softwareVersion"\s*:\s*"([^"]+)"', html)
if m:
    version = m.group(1)
    log(f"Version found: {version}")
else:
    m2 = re.search(r'v(\d+\.\d+\.\d+)', html)
    version = m2.group(0) if m2 else "v1.0.3"
    log(f"Version (fallback): {version}")

# ── 3. Extract Description ────────────────────────────────────────────────────
m = re.search(r'"description"\s*:\s*"([^"]+)"', html)
if m:
    description = m.group(1)
    log(f"Description found: {description[:80]}...")
else:
    description = (
        "A life simulator where you are free to do whatever you like without any "
        "restriction. Welcome to the various maps and activities of one state rp "
        "mod apk with unlimited money and diamonds."
    )
    log("Description (fallback used)")

# ── 4. Extract Thumbnail ──────────────────────────────────────────────────────
m = re.search(r'"thumbnailUrl"\s*:\s*"([^"]+)"', html)
if m:
    raw = m.group(1)
    thumb_url = raw if raw.startswith("http") else f"https://getmodsapk.com{raw}"
    log(f"Thumbnail: {thumb_url}")
else:
    thumb_url = "https://getmodsapk.com/storage/media/2025/12/onestate-rp-mod-apk.webp"
    log("Thumbnail (fallback)")

# ── 5. Extract Screenshots ────────────────────────────────────────────────────
screenshots = list(dict.fromkeys(
    re.findall(
        r'data-src="(https://getmodsapk\.com/storage/media/[^"]+one-state[^"]+\.webp)"',
        html
    )
))
if not screenshots:
    screenshots = [
        "https://getmodsapk.com/storage/media/2025/8/one-state-rp-mod-apk-2.webp",
        "https://getmodsapk.com/storage/media/2025/8/one-state-rp-mod-apk-1.webp",
        "https://getmodsapk.com/storage/media/2025/8/one-state-rp-mod-apk-3.webp",
    ]
    log("Screenshots (fallback used)")
else:
    log(f"Screenshots found: {len(screenshots)}")

# ── Download & Convert Scraped Images ────────────────────────────────────────
ensure_static_images()
local_thumb_url = download_and_convert_to_jpg(thumb_url, "thumbnail")

local_screenshots = []
for idx, screenshot_url in enumerate(screenshots, 1):
    local_path = download_and_convert_to_jpg(screenshot_url, f"screenshot_{idx}")
    local_screenshots.append(local_path)

# ── 6. Extract Last Updated Date ─────────────────────────────────────────────
m = re.search(r'"dateModified"\s*:\s*"(\d{4}-\d{2}-\d{2})', html)
if m:
    parsed = datetime.datetime.strptime(m.group(1), "%Y-%m-%d")
    last_updated = parsed.strftime("%B %d, %Y")
    log(f"Last updated: {last_updated}")
else:
    last_updated = datetime.datetime.now(datetime.timezone.utc).strftime("%B %d, %Y")
    log("Last updated (today's date used)")

# ── 7. Extract File Size ──────────────────────────────────────────────────────
m = re.search(r'"fileSize"\s*:\s*"([^"]+)"', html)
file_size = m.group(1) if m else "125 MB"
log(f"File size: {file_size}")

# ── 8. Read existing index.html ───────────────────────────────────────────────
if not INDEX_FILE.exists():
    log(f"ERROR: index.html not found at {INDEX_FILE}")
    sys.exit(1)
content = INDEX_FILE.read_text(encoding="utf-8")
log(f"index.html loaded ({len(content)} bytes)")

# ── 9. Update Version Badge ───────────────────────────────────────────────────
content = re.sub(
    r'OFFICIAL ONESTATE APK v[\d\.]+',
    f"OFFICIAL ONESTATE APK {version}",
    content
)
content = re.sub(
    r'data-version="[^"]*"',
    f'data-version="{version}"',
    content
)

# ── 10. Update Gallery / Screenshot Images ────────────────────────────────────
screenshot_block = ""
for i, img_url in enumerate(local_screenshots, 1):
    screenshot_block += (
        f'                <div class="gallery-item reveal">\n'
        f'                    <img class="gallery-img" src="{img_url}" '
        f'alt="OneState RP Mod Screenshot {i}" loading="lazy">\n'
        f'                    <div class="gallery-overlay">'
        f'<span class="gallery-caption">Screenshot {i}</span></div>\n'
        f'                </div>\n'
    )

content = re.sub(
    r'(<div class="gallery-grid">).*?(</div>\s*</section>)',
    lambda m2: m2.group(1) + "\n" + screenshot_block + "            " + m2.group(2),
    content,
    flags=re.DOTALL
)

# ── 11. Update live-data JSON block ──────────────────────────────────────────
screenshots_json = json.dumps(local_screenshots)
data_script = (
    '<script id="live-data" type="application/json">\n'
    '{\n'
    f'  "version": "{version}",\n'
    f'  "lastUpdated": "{last_updated}",\n'
    f'  "fileSize": "{file_size}",\n'
    f'  "thumbnailUrl": "{local_thumb_url}",\n'
    f'  "description": "{description}",\n'
    f'  "screenshots": {screenshots_json}\n'
    '}\n'
    '</script>'
)

if re.search(r'<script id="live-data"', content):
    content = re.sub(
        r'<script id="live-data"[^>]*>.*?</script>',
        data_script,
        content,
        flags=re.DOTALL
    )
else:
    content = content.replace("</head>", f"{data_script}\n</head>")

# ── 12. Update meta description ───────────────────────────────────────────────
meta_desc = f"Download One State RP Mod {version}. {description}"
if len(meta_desc) > 160:
    meta_desc = meta_desc[:157] + "..."
content = re.sub(
    r'(<meta name="description"\s+content=")[^"]*(")',
    lambda m2: m2.group(1) + meta_desc + m2.group(2),
    content
)

# ── 13. Write updated index.html ──────────────────────────────────────────────
try:
    INDEX_FILE.write_text(content, encoding="utf-8")
    log("index.html updated successfully!")
except Exception as e:
    log(f"ERROR: Failed to write index.html – {e}")
    sys.exit(1)

log(f"=== Auto-Update Complete. Version: {version} | Updated: {last_updated} ===")
