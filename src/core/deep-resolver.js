#!/usr/bin/env node
/**
 * MrStream-Cli Deep Resolver
 *
 * Loads Clappr/AKS embed pages in a headless browser, executes JavaScript to
 * decode obfuscated stream configs (window._econfig), monitors network requests
 * for m3u8 URLs, and outputs the resolved stream URL.
 *
 * Usage:
 *   node deep-resolver.js <embed-url> [referer-url]
 *
 * Output (stdout):
 *   <m3u8-url>
 *   <referer>
 *
 * Exit code: 0 on success, 1 on failure.
 */

const { chromium } = require('playwright');

const TIMEOUT = 30000;
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0';

(async () => {
  const targetUrl = process.argv[2];
  const referer = process.argv[3] || targetUrl;

  if (!targetUrl) {
    console.error('Usage: node deep-resolver.js <url> [referer]');
    process.exit(1);
  }

  let resolvedUrl = null;
  let browser;

  try {
    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });

    const context = await browser.newContext({
      userAgent: UA,
      viewport: { width: 1280, height: 720 },
      extraHTTPHeaders: {
        Referer: referer,
        Origin: new URL(referer).origin,
      },
    });

    const page = await context.newPage();

    // Monitor all network requests for .m3u8 URLs
    page.on('request', request => {
      const url = request.url();
      if (url.includes('.m3u8')) resolvedUrl = url;
    });

    // Also check responses (some appear in redirect chains)
    page.on('response', response => {
      const url = response.url();
      if (url.includes('.m3u8')) resolvedUrl = url;
    });

    // Navigate and wait for network to settle
    await page.goto(targetUrl, {
      waitUntil: 'networkidle',
      timeout: TIMEOUT,
    });

    // Wait for _econfig or a reasonable timeout
    await page.waitForFunction(
      () => typeof window._econfig !== 'undefined',
      { timeout: 5000 }
    ).catch(() => {});

    // --- Strategy 1: Check network-captured m3u8 URLs ---
    if (resolvedUrl) {
      await browser.close();
      console.log(resolvedUrl);
      console.log(referer);
      process.exit(0);
    }

    // --- Strategy 2: Extract and decode window._econfig ---
    let econfigRaw;
    try {
      econfigRaw = await page.evaluate(() => {
        if (typeof window._econfig === 'string') return window._econfig;
        if (typeof window._econfig === 'object' && window._econfig !== null) {
          return JSON.stringify(window._econfig);
        }
        return null;
      });
    } catch (_) {}

    if (econfigRaw) {
      const decoded = Buffer.from(econfigRaw, 'base64').toString('utf-8');
      const m3u8Match = decoded.match(/https?:\/\/[^\s"']+\.m3u8[^\s"']*/);
      if (m3u8Match) {
        await browser.close();
        console.log(m3u8Match[0]);
        console.log(referer);
        process.exit(0);
      }

      // Check for JSON config with source/file keys
      try {
        const config = JSON.parse(decoded);
        const streamUrl =
          config?.source || config?.file || config?.url ||
          config?.stream || config?.playlist || config?.hls;
        if (streamUrl && typeof streamUrl === 'string') {
          await browser.close();
          console.log(streamUrl);
          console.log(referer);
          process.exit(0);
        }
      } catch (_) {}

      // Last-ditch: any http/https URL in decoded content
      const anyUrl = decoded.match(/https?:\/\/[^\s"']+/);
      if (anyUrl) {
        await browser.close();
        console.log(anyUrl[0]);
        console.log(referer);
        process.exit(0);
      }
    }

    // --- Strategy 3: Click play/watch buttons ---
    const buttons = await page.$$('button, a, .play-button, .watch-button, [onclick]');
    for (const btn of buttons) {
      try {
        const text = await btn.innerText();
        if (/play|watch|start|stream/i.test(text)) {
          await btn.click().catch(() => {});
          await page.waitForTimeout(2000);

          const playerSrc = await page.evaluate(() => {
            const el = document.querySelector('video source');
            return el ? el.src : null;
          }).catch(() => null);

          if (playerSrc && playerSrc.includes('.m3u8')) {
            await browser.close();
            console.log(playerSrc);
            console.log(referer);
            process.exit(0);
          }
        }
      } catch (_) {}
    }

    // --- Strategy 4: Check DOM for data attributes or video elements ---
    const videoSources = await page.evaluate(() => {
      const sources = [];
      document.querySelectorAll(
        'video source, video, [data-src], [data-url], [data-stream]'
      ).forEach(el => {
        const src = el.src ||
          el.getAttribute('data-src') ||
          el.getAttribute('data-url') ||
          el.getAttribute('data-stream');
        if (src) sources.push(src);
      });
      return sources;
    }).catch(() => []);

    for (const src of videoSources) {
      if (src.includes('.m3u8') || src.includes('.mp4') || src.includes('.ts')) {
        await browser.close();
        console.log(src);
        console.log(referer);
        process.exit(0);
      }
    }

    await browser.close();
    process.exit(1);
  } catch (e) {
    if (browser) await browser.close().catch(() => {});
    console.error('Deep resolver error:', e.message);
    process.exit(1);
  }
})();
