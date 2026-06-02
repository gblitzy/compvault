import { Actor } from 'apify';
import { CheerioCrawler, log } from 'crawlee';

await Actor.init();

/* ------------------------------------------------------------------ *
 * Input
 * ------------------------------------------------------------------ */
const input = (await Actor.getInput()) ?? {};
const {
    searchTerms = [],
    ebayDomain = 'www.ebay.com',
    itemsPerPage = 240,
    maxPagesPerSearch = 3,
    maxItems = 0,
    proxyConfiguration: proxyInput,
} = input;

if (!Array.isArray(searchTerms) || searchTerms.length === 0) {
    throw new Error('Input "searchTerms" must be a non-empty array of keyword strings.');
}

const proxyConfiguration = await Actor.createProxyConfiguration(
    proxyInput ?? { useApifyProxy: true, apifyProxyGroups: ['RESIDENTIAL'] },
);

if (!proxyConfiguration) {
    log.warning(
        'No proxy is configured. eBay aggressively blocks datacenter / unproxied traffic — '
        + 'RESIDENTIAL proxies are strongly recommended or you will hit captchas within minutes.',
    );
}

/* ------------------------------------------------------------------ *
 * Helpers
 * ------------------------------------------------------------------ */

// Build a sold + completed listings search URL.
const buildSearchUrl = (term, page) => {
    const u = new URL(`https://${ebayDomain}/sch/i.html`);
    u.searchParams.set('_nkw', term);
    u.searchParams.set('LH_Sold', '1');      // sold items only
    u.searchParams.set('LH_Complete', '1');  // completed listings only
    u.searchParams.set('_ipg', String(itemsPerPage));
    u.searchParams.set('_pgn', String(page));
    return u.href;
};

// Pull the numeric eBay item id out of a listing URL.
const extractItemId = (url) => {
    if (!url) return null;
    const m = url.match(/\/itm\/(?:[^/]*\/)?(\d{6,})/);
    return m ? m[1] : null;
};

// Parse a price string like "$12.50", "£10.00 to £20.00", "C $9.99" into structured fields.
const parsePrice = (raw) => {
    if (!raw) return { priceRaw: null, priceMin: null, priceMax: null, currency: null };
    const text = raw.replace(/\s+/g, ' ').trim();
    const currencyMatch = text.match(/[A-Z]{1,3}\s?\$|[$£€¥]|[A-Z]{3}/);
    const numbers = (text.match(/[\d][\d,]*(?:\.\d+)?/g) || [])
        .map((n) => Number(n.replace(/,/g, '')))
        .filter((n) => !Number.isNaN(n));
    return {
        priceRaw: text,
        priceMin: numbers.length ? numbers[0] : null,
        priceMax: numbers.length ? numbers[numbers.length - 1] : null,
        currency: currencyMatch ? currencyMatch[0].trim() : null,
    };
};

// Parse the sold-date caption like "Sold  Mar 15, 2026" into an ISO date.
const parseSoldDate = (raw) => {
    if (!raw) return { soldDateRaw: null, soldDate: null };
    const text = raw.replace(/\s+/g, ' ').trim();
    const m = text.match(/([A-Za-z]{3}\s+\d{1,2},\s+\d{4})/);
    let iso = null;
    if (m) {
        const d = new Date(m[1]);
        if (!Number.isNaN(d.getTime())) iso = d.toISOString().slice(0, 10);
    }
    return { soldDateRaw: text, soldDate: iso };
};

const firstText = ($card, selectors) => {
    for (const sel of selectors) {
        const t = $card.find(sel).first().text().replace(/\s+/g, ' ').trim();
        if (t) return t;
    }
    return null;
};

/* ------------------------------------------------------------------ *
 * Crawler
 * ------------------------------------------------------------------ */
let scrapedCount = 0;
const limitReached = () => maxItems > 0 && scrapedCount >= maxItems;

const startRequests = searchTerms.map((term) => ({
    url: buildSearchUrl(String(term), 1),
    userData: { term: String(term), page: 1 },
}));

const crawler = new CheerioCrawler({
    proxyConfiguration,
    maxConcurrency: 8,
    maxRequestRetries: 5,
    requestHandlerTimeoutSecs: 60,
    // got-scraping (used under the hood) rotates realistic browser headers and TLS fingerprints automatically.

    async requestHandler({ $, request, addRequests }) {
        const { term, page } = request.userData;

        // eBay uses li.s-item (and is rolling out li.s-card in some layouts).
        const cards = $('li.s-item, li.s-card');

        if (cards.length === 0) {
            const body = $('body').text().toLowerCase();
            if (
                body.includes('captcha')
                || body.includes('pardon our interruption')
                || body.includes('checking your browser')
                || body.includes('access denied')
            ) {
                // Throwing triggers a retry, which got-scraping serves through a fresh proxy session.
                throw new Error('Anti-bot / interstitial page detected — retrying via a new proxy session.');
            }
            log.warning(`No listing cards found for "${term}" page ${page}. Likely a DOM change or genuinely no results.`);
        }

        const items = [];
        cards.each((_, el) => {
            if (limitReached()) return false; // stop iterating once the global cap is hit
            const card = $(el);

            const link = card.find('a.s-item__link, a.s-card__link').attr('href')
                || card.find('a[href*="/itm/"]').attr('href')
                || null;
            const itemId = extractItemId(link);
            if (!itemId) return; // skips the leading "Shop on eBay" placeholder and malformed rows

            const title = firstText(card, ['.s-item__title', '.s-card__title']);
            if (!title || /^shop on ebay$/i.test(title)) return;

            const { priceRaw, priceMin, priceMax, currency } = parsePrice(
                firstText(card, ['.s-item__price', '.s-card__price']),
            );
            const { soldDateRaw, soldDate } = parseSoldDate(
                firstText(card, ['.s-item__caption--signal', '.s-item__caption', '.s-card__caption']),
            );

            const image = card.find('.s-item__image-wrapper img, .s-item__image img, img.s-card__image').attr('src')
                || card.find('img').attr('data-src')
                || null;

            items.push({
                searchTerm: term,
                itemId,
                title,
                priceRaw,
                priceMin,
                priceMax,
                currency,
                soldDateRaw,
                soldDate,
                condition: firstText(card, ['.SECONDARY_INFO', '.s-item__subtitle']),
                shipping: firstText(card, ['.s-item__shipping', '.s-item__logisticsCost']),
                bids: firstText(card, ['.s-item__bids', '.s-item__bidCount']),
                imageUrl: image,
                url: link ? link.split('?')[0] : null,
                scrapedAt: new Date().toISOString(),
            });
        });

        // Respect the global cap precisely.
        let toPush = items;
        if (maxItems > 0) {
            const remaining = Math.max(0, maxItems - scrapedCount);
            toPush = items.slice(0, remaining);
        }
        if (toPush.length) {
            await Actor.pushData(toPush);
            scrapedCount += toPush.length;
        }
        log.info(`"${term}" page ${page}: pushed ${toPush.length} sold items (running total ${scrapedCount}).`);

        // Enqueue the next page if there is more to fetch.
        if (!limitReached() && page < maxPagesPerSearch && items.length > 0) {
            await addRequests([{
                url: buildSearchUrl(term, page + 1),
                userData: { term, page: page + 1 },
            }]);
        }
    },

    failedRequestHandler({ request, error }) {
        log.error(`Request ${request.url} failed after all retries: ${error?.message}`);
    },
});

await crawler.run(startRequests);

log.info(`Done. Scraped ${scrapedCount} sold listing(s) across ${searchTerms.length} search term(s).`);

await Actor.exit();
