export type Client = ReturnType<typeof createClient>;

export function createClient() {
  const hrsToMs = 60 * 60 * 1000;
  const maxCacheAgeMs = 2 * hrsToMs;
  let isFirstFetch = true;
  const userAgents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
  ];

  const headers: HeadersInit = {
    "User-Agent": userAgents[Math.floor(Math.random() * userAgents.length)],
  };

  function makeHeaders(extraHeaders: HeadersInit = {}, cookies: string[] = []) {
    return {
      ...extraHeaders,
      ...headers,
      Cookie: cookies.length ? cookies.join("; ") : "",
    };
  }

  async function deleteCachedResponse(key: Request, cache: Cache) {
    console.log(`Deleting cached response for ${key.url}`);
    await cache.delete(key);
  }

  async function timeoutPastCache(cache: Cache) {
    const keys = await cache.keys();
    const now = Date.now();
    for (const key of keys) {
      const response = await cache.match(key);
      if (!response) continue;
      const dateStr = response.headers.get("date");
      if (!dateStr) {
        await deleteCachedResponse(key, cache);
        continue;
      }
      const date = new Date(dateStr);
      const cacheDurationMs = now - date.getTime();
      const durationTillDeleteMs = maxCacheAgeMs - cacheDurationMs;
      if (durationTillDeleteMs <= 0) {
        await deleteCachedResponse(key, cache);
      } else {
        setTimeout(async () => {
          await deleteCachedResponse(key, cache);
        }, durationTillDeleteMs);
      }
    }
  }

  async function cachedFetch(url: string, init?: RequestInit) {
    const cache = await caches.open("sentorr-cache");
    if (isFirstFetch) {
      isFirstFetch = false;
      timeoutPastCache(cache);
    }
    const request = new Request(url, { cache: "no-store", ...init });
    const cachedResponse = await cache.match(request);
    if (cachedResponse) {
      console.log(`Serving cached response for ${url}`);
      return cachedResponse;
    }
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      console.log(`Caching response for ${url}`);
      cache.put(request, networkResponse.clone());
      setTimeout(() => {
        deleteCachedResponse(request, cache);
      }, maxCacheAgeMs);
    }

    return networkResponse;
  }

  async function get(
    url: string,
    extraHeaders?: HeadersInit,
    cookies?: string[],
  ) {
    return cachedFetch(url, {
      method: "GET",
      headers: makeHeaders(extraHeaders, cookies),
    });
  }

  async function post(
    url: string,
    data: any,
    extraHeaders?: HeadersInit,
    cookies?: string[],
  ) {
    return cachedFetch(url, {
      method: "POST",
      headers: makeHeaders(
        { "Content-Type": "application/json", ...extraHeaders },
        cookies,
      ),
      body: JSON.stringify(data),
    });
  }

  return { get, post };
}
