/**
 * Screenshot utility using Puppeteer
 *
 * Usage:
 *   npx tsx screenshot.ts --url <url> --output <path> [options]
 *
 * Options:
 *   --url <url>           URL to screenshot (required)
 *   --output <path>       Output file path (required)
 *   --viewport <WxH>      Viewport dimensions (default: 1200x900)
 *   --wait <ms>           Wait time after load (default: 2000)
 *   --full-page           Capture full page height
 */

import * as fs from 'fs';
import * as path from 'path';
import puppeteer from 'puppeteer';

interface Options {
  url: string;
  output: string;
  viewport: { width: number; height: number };
  wait: number;
  fullPage: boolean;
}

function parseArgs(): Options {
  const args = process.argv.slice(2);
  const options: Options = {
    url: '',
    output: '',
    viewport: { width: 1200, height: 900 },
    wait: 2000,
    fullPage: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const next = args[i + 1];

    switch (arg) {
      case '--url':
        options.url = next || '';
        i++;
        break;
      case '--output':
        options.output = next || '';
        i++;
        break;
      case '--viewport':
        if (next) {
          const [w, h] = next.split('x').map(Number);
          if (w && h) {
            options.viewport = { width: w, height: h };
          }
        }
        i++;
        break;
      case '--wait':
        options.wait = parseInt(next || '2000', 10);
        i++;
        break;
      case '--full-page':
        options.fullPage = true;
        break;
    }
  }

  return options;
}

async function takeScreenshot(options: Options): Promise<void> {
  if (!options.url) {
    console.error('Error: --url is required');
    process.exit(1);
  }

  if (!options.output) {
    console.error('Error: --output is required');
    process.exit(1);
  }

  // Ensure output directory exists
  const dir = path.dirname(options.output);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // Launch browser
  const browser = await puppeteer.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920,1080',
    ],
  });

  try {
    const page = await browser.newPage();

    // Set viewport
    await page.setViewport(options.viewport);

    // Navigate to URL
    console.log(`Navigating to: ${options.url}`);
    await page.goto(options.url, {
      waitUntil: 'networkidle0',
      timeout: 30000,
    });

    // For demo showcase pages, scroll to the slide section
    const url = new URL(options.url);
    const slide = url.searchParams.get('slide');
    if (slide && options.url.includes('/demo/fever/showcase')) {
      console.log(`Scrolling to slide section: ${slide}`);

      // Map from our slide IDs to the actual DOM element IDs used in the showcase page
      const slideIdToElementId: Record<string, string> = {
        'cast-assignment': 'demo-cast',
        'contract-acceptance': 'demo-contracts',
        'event-creation': 'demo-events',
        'hire-order-view': 'demo-hire-orders',
        'invoice-download': 'demo-invoice-download',
        'invoice-validate': 'demo-invoices',
        'reimbursement-upload': 'demo-reimbursements',
      };

      const elementId = slideIdToElementId[slide] || slide;

      // Scroll to the section using the mapped element ID
      await page.evaluate((targetId) => {
        const element = document.getElementById(targetId);
        if (element) {
          element.scrollIntoView({ behavior: 'instant', block: 'center' });
        } else {
          // Fallback: scroll down to demo section area (about 60% of page)
          console.log(`Element #${targetId} not found, using fallback scroll`);
          window.scrollTo(0, document.body.scrollHeight * 0.4);
        }
      }, elementId);

      // Wait for scroll to complete
      await new Promise((resolve) => setTimeout(resolve, 500));
    }

    // Wait for any animations to settle
    if (options.wait > 0) {
      console.log(`Waiting ${options.wait}ms for animations...`);
      await new Promise((resolve) => setTimeout(resolve, options.wait));
    }

    // Take screenshot
    console.log(`Saving screenshot to: ${options.output}`);
    await page.screenshot({
      path: options.output,
      fullPage: options.fullPage,
    });

    console.log('Screenshot captured successfully!');
  } catch (error) {
    console.error('Screenshot failed:', error);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

// Run
const options = parseArgs();
takeScreenshot(options).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
