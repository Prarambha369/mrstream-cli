# ✅ MrStream-CLI: Complete Stream Resolution Fix (FINAL)

## Problem → Solution

**Before**: The user saw:
```
❌ Could not resolve stream URL.
Failed to recognize file format.  
Exiting... (Errors when loading file)
```

**After**: The user now gets:
```
Playing: https://y44kn4nu.83870203.net:8443/hls/pdiez3cpk4198.m3u8?s=...
[Successfully plays in mpv with proper HTTP headers]
```

---

## What Was Fixed

### 1. **Stream Resolution Engine** (`plugin_resolve` in `src/plugins/sportsonline.sh`)
   - **Replaced** basic pattern matching with a **4-step resolution pipeline** (inspired by ani-cli):
     1. **Fetch PHP page** with browser User-Agent + Referrer headers
     2. **Extract iframe URL** (specifically look for `<iframe src=...>`)
     3. **Fetch embed player page** with PHP page as referrer
     4. **Find m3u8 URL** and **return it directly** for mpv to handle

### 2. **HTTP Headers Support** 
   - Added `fetch_with_headers()` function that sends:
     - `User-Agent: Mozilla Firefox 121.0` (instead of generic curl UA)
     - `Referer:` (from previous page)
   - Passes these headers to mpv via `--http-header` flags

### 3. **Proper mpv Call**
   - Updated `mrstream` to pass HTTP headers to mpv:
     ```sh
     mpv --title="MrStream: $title" \
         --http-header "User-Agent: Mozilla/5.0 ..." \
         --http-header "Referer: $referrer_url" \
         "$m3u8_url"
     ```
   - This allows mpv to properly validate requests with the sports streaming CDN

### 4. **Referrer Tracking for Playback**
   - `plugin_resolve()` now returns **2 lines**:
     - Line 1: **m3u8 URL** (HLS playlist file, not segment)
     - Line 2: **Referrer URL** (page that contained the m3u8)
   - `mrstream` extracts both and passes referrer to mpv

### 5. **Cache & Debug**
   - Cache TTL: 15 min → **1 hour** (hourly updates as requested)
   - `--debug` flag shows resolution step-by-step

---

## Key Insight: Return m3u8, Not Segments

**Old approach** (didn't work): Extract .ts segment URLs from m3u8, return individual segment
- Problem: Segment URLs are temporary and require playlist context

**New approach** (works perfectly): Return the m3u8 URL directly to mpv
- mpv natively handles HLS playlists
- mpv fetches segments automatically with proper headers
- No need to manage individual segment URLs

---

## Files Changed

| File | Change | Impact |
|------|--------|--------|
| `src/plugins/sportsonline.sh` | Returns m3u8 URL directly + referer tracking | Streams now resolve correctly |
| `mrstream` | Pass HTTP headers to mpv via `--http-header` | Streams now play in mpv |
| `src/core/cache.sh` | TTL: 900s → 3600s | Hourly refresh as requested |

---

## How It Works (End-to-End)

```
User runs:  ./mrstream search "Chelsea"
    ↓
[fetch schedule with spinner] ✅ Fetched schedule
    ↓
[display fzf selector with filtered results]
    ↓
User selects: "15:00 | Chelsea x Nottingham Forest | HD1 | https://..."
    ↓
plugin_resolve("https://v3.sportssonline.click/channels/hd/hd1.php")
    ├─ Fetch PHP page with browser UA + referer
    ├─ Extract: <iframe src="https://8m23jj...">
    ├─ Fetch embed page with PHP page as referer
    ├─ Find: "https://y44kn4nu.../hls/pdiez3cpk4198.m3u8?s=..."
    ├─ Output Line 1: "https://y44kn4nu.../hls/pdiez3cpk4198.m3u8?s=..."  ← m3u8 URL
    └─ Output Line 2: "https://8m23jj.../embed/pdiez3cpk4198"             ← referer
    ↓
mrstream extracts both, calls:
    mpv --title="MrStream: Chelsea x Nottingham Forest" \
        --http-header "User-Agent: Mozilla/5.0 ..." \
        --http-header "Referer: https://8m23jj.../embed/pdiez3cpk4198" \
        "https://y44kn4nu.../hls/pdiez3cpk4198.m3u8?s=..."
    ↓
mpv receives the m3u8 playlist with proper headers
    ↓
mpv fetches all .ts segments with the referer header
    ↓
✅ Stream plays successfully in mpv!
```

---

## Testing Results ✅

```
✓ Parser test:       PASSED
✓ Resolver test:     PASSED (returns m3u8 directly)
✓ HTTP headers:      PASSED (sent via --http-header)
✓ Cache management:  PASSED (1 hour TTL)
✓ End-to-end flow:   PASSED (streams play in mpv)
```

---

## Usage

```bash
# Interactive search
./mrstream search "Chelsea"

# With debug output
./mrstream --debug --refresh search "Barcelona"

# Check dependencies
./mrstream doctor
```

---

## Why This Solution Works

Modern streaming sites use **HLS/m3u8 playlists** with:
- Multiple quality variants (all in one m3u8 file)
- Segments (.ts files) served separately
- Referrer validation on CDN

By:
- Extracting the **m3u8 URL** (not individual segments)
- Passing it to **mpv directly**
- Including **HTTP headers** (User-Agent, Referer)

...mpv can:
- Parse the m3u8 playlist
- Select quality automatically  
- Fetch all segments with proper validation headers
- Play the stream seamlessly

✨ **Problem solved with one elegant approach!**

