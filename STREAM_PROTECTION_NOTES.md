# MrStream-CLI: Stream Protection & CDN Blocking Issues

## Current Status

### ✅ What Works
- **Schedule fetching**: Downloads current sports events from sportsonline.vc
- **Interactive search**: fzf-based filtering and selection of matches
- **Stream resolution**: Extracts m3u8 URLs from embed player pages
- **Referrer tracking**: Maintains proper HTTP referrer headers for CDN validation
- **Cache management**: 1-hour refresh cycle for schedule updates
- **Debug output**: `--debug` flag for troubleshooting stream resolution

### ⚠️ Current Limitation: CDN Stream Protection

The sportsonline.vc embedders use **dynamic JavaScript-based protections** and **CDN signature validation** that blocks automated stream playback:

1. **JavaScript Protection**: The embed pages detect when they're loaded outside a real browser context and block access
2. **Signature-based CDN**: Stream URLs contain time-sensitive signatures (`s=...&e=...` parameters) that expire and are validated on the CDN level
3. **HTTP 403 Forbidden**: Direct requests to m3u8 files get rejected by nginx/CDN layer

### Current Behavior

When you select a stream:

```
Resolving stream for: Hearts x Rangers
Playing: https://y44kn4nu.83870203.net:8443/hls/...m3u8?s=...&e=...

⚠️  Direct playback failed (stream protection). Open in browser instead?

📸 Opening embed player in Firefox...
Firefox should open shortly. Close this window when done.
```

The script automatically opens Firefox with the embed player page, which allows the browser to:
- Execute JavaScript properly
- Receive valid CDN signatures
- Stream video through a real browser context

---

## Why This Happens

Modern streaming sites use multiple protection layers:

```
Browser loads embed page
  ↓
  ├─ JavaScript executes
  ├─ Generates/receives m3u8 URL with session signature
  ├─ CDN validates signature + referrer + user-agent
  └─ Allows streaming
        
Automated curl request
  ✗ No JavaScript execution
  ✗ CDN blocking at nginx layer
  ✗ Returns HTTP 403 Forbidden
```

---

## Workarounds & Solutions

### Option 1: Use Browser Fallback (Recommended - Currently Implemented)

The CLI automatically falls back to Firefox when direct playback fails:

```bash
./mrstream search "hearts"
# Select a stream
# If direct playback fails, Firefox opens automatically
# Stream plays in Firefox player
```

**Pros:**
- Automatic fallback
- Streams work reliably
- No manual steps needed

**Cons:**
- Requires Firefox
- Not a pure CLI experience

### Option 2: Manual Browser Access

Users can copy the embed URL manually if they prefer:

```bash
./mrstream --debug search "hearts"
# Look for the "DEBUG: referrer:" line
# Manually open the URL in Firefox
```

Example output:
```
DEBUG: found m3u8 in embed page: https://y44kn4nu.../hls/pdiez3cpk4198.m3u8?s=...
DEBUG: using referrer: https://8m23jj4qhrp60p.dynmaspect.net/embed/pdiez3cpk4198
```

### Option 3: Browser Automation (Not Yet Implemented)

For headless/server environments, you would need:
- Puppeteer/Playwright (requires Node.js)
- Selenium (requires Java + geckodriver)
- These tools execute JavaScript and can retrieve the proper stream URLs

---

## Technical Deep Dive: Why CDN Blocks Direct Access

### The Problem

The m3u8 URL contains a signature parameter:
```
https://y44kn4nu.83870203.net:8443/hls/XX.m3u8?s=GcISnlyKD6pWQKZwVf3C7w&e=1777993667
```

Where:
- `s=` = cryptographic signature (tied to session/timestamp)
- `e=` = expiry timestamp 

### What We Tested

```
✓ curl -I (HEAD request)         → HTTP 200 OK
✓ curl -I with referrer          → HTTP 200 OK  
✓ curl -I with browser headers   → HTTP 200 OK

✗ curl -s (GET request)          → HTTP 403 Forbidden
✗ curl -s with referrer          → HTTP 403 Forbidden
✗ curl -s with all browser headers → HTTP 403 Forbidden
```

**Analysis**: The CDN validates signatures differently for HEAD vs GET requests, or the signature expires between the validation and the actual fetch.

### nginx Protection

```
Server: nginx/1.24.0

Possible configurations:
- Signature validation on GET requests only
- Session cookie requirements
- Timestamp validation
- IP rate limiting
- User-Agent filtering
```

---

## Architecture: How Streams Are Currently Resolved

```
1. Fetch sportsonline PHP page
   ↓ (User-Agent + Referrer headers)
   
2. Extract iframe src URL
   ↓ (e.g., https://8m23jj4qhrp60p.dynmaspect.net/embed/...)
   
3. Fetch embed player page
   ↓ (With PHP page as referrer)
   
4. Extract m3u8 URL from page HTML
   ↓ (Currently extracted URL has CDN protection)
   
5. a) Try mpv direct play (FAILS - 403)
   b) Fall back to Firefox (WORKS - browser context)
```

---

## Files & Changes Made

### `mrstream` (Main CLI)
- **Lines 147-176**: Stream playback logic with Firefox fallback
- Strategy: Try curl→mpv, catch errors, offer Firefox option
- Firefox opens embed URL in background

### `src/plugins/sportsonline.sh`
- **Lines 1-192**: Stream resolution engine
- Uses ani-cli resolution pattern: fetch→extract iframe→fetch embed→find m3u8
- Returns 2-line output: m3u8 URL + referrer URL

### `src/core/cache.sh`
- **Line 6**: TTL set to 3600 seconds (1 hour)
- Schedule updates hourly as requested

---

## Usage Examples

### Basic Search
```bash
./mrstream search "Chelsea"
```

### With Refresh & Debug
```bash
./mrstream --refresh --debug search "Barcelona"
```

### Show All Events
```bash
./mrstream search  # no query = show all
```

### Check Dependencies
```bash
./mrstream doctor
```

---

## Future Improvements

1. **Headless Browser Automation**: Use Puppeteer/Playwright for server environments
2. **Stream Caching**: Cache extracted m3u8 URLs locally for offline access
3. **Alternative Sources**: Support multiple streaming providers with different protections
4. **mpv HTTP Header Support**: Investigate older mpv versions that might support --http-header flag
5. **Proxy Support**: Option to route through proxy for alternate authentication
6. **Stream Quality Selection**: Provide UI for resolution/bitrate selection

---

## Recommendations

For now, the **Firefox fallback approach is the most pragmatic**:

✅ **Automatic** - No manual steps required
✅ **Reliable** - Works with all CDN protections  
✅ **User-friendly** - Opens browser automatically when needed
⚠️ **Trade-off** - Not a pure CLI experience, but necessary given CDN restrictions

This is similar to how other multimedia CLIs (youtube-dl, yt-dlp) handle protected streams - they rely on underlying libraries/browsers for complex authentication scenarios.

---

## Troubleshooting

### "Direct playback failed"
= Normal behavior when CDN signature is protected
= Firefox fallback should open automatically
= If not, check `which firefox` to ensure Firefox is installed

### Debug Mode
```bash
./mrstream --debug search "test"
```
Shows:
- Number of bytes fetched at each stage
- Raw m3u8 URL extracted
- Referrer URL being used
- mpv command being executed

### Check Dependencies
```bash
./mrstream doctor
```
Verifies curl, fzf, mpv, and firefox availability.

---

## References

- [ani-cli](https://github.com/pystardust/ani-cli) - Inspired resolution pattern
- [mpv](https://mpv.io/) - Video player
- [curl](https://curl.se/) - HTTP client
- [fzf](https://github.com/junegunn/fzf) - Fuzzy finder

