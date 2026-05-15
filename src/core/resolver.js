const { chromium } = require('playwright');

(async () => {
    const targetUrl = process.argv[2];
    if (!targetUrl) {
        process.exit(1);
    }

    let resolvedUrl = null;

    try {
        // Launch CloakBrowser / Stealth Chromium
        const browser = await chromium.launch({ 
            headless: true,
            // If using CloakBrowser, the executablePath would be set here
            // executablePath: '/path/to/cloak-browser' 
        });
        
        const context = await browser.newContext({
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            viewport: { width: 1280, height: 720 }
        });

        const page = await context.newPage();

        // Monitor network requests for any .m3u8 link
        page.on('request', request => {
            const url = request.url();
            if (url.includes('.m3u8')) {
                resolvedUrl = url;
            }
        });

        // Go to the target page and wait for the network to settle
        await page.goto(targetUrl, { waitUntil: 'networkidle', timeout: 30000 });

        // Some streams require a click on a "Watch" button
        const buttons = await page.$$('button, a');
        for (const btn of buttons) {
            const text = await btn.innerText();
            if (text.toLowerCase().includes('watch') || text.toLowerCase().includes('play')) {
                await btn.click().catch(() => {});
                await page.waitForTimeout(2000); // Wait for JS to trigger
                if (resolvedUrl) break;
            }
        }

        await browser.close();

        if (resolvedUrl) {
            console.log(resolvedUrl);
            process.exit(0);
        } else {
            process.exit(1);
        }
    } catch (e) {
        process.exit(1);
    }
})();
