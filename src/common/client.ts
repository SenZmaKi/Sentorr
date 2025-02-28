export type Client = ReturnType<typeof createClient>;

export function createClient() {
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

  async function get(
    url: string,
    extraHeaders?: HeadersInit,
    cookies?: string[]
  ) {
    return fetch(url, {
      method: "GET",
      headers: makeHeaders(extraHeaders, cookies),
    });
  }

  async function post(
    url: string,
    data: any,
    extraHeaders?: HeadersInit,
    cookies?: string[]
  ) {
    return fetch(url, {
      method: "POST",
      headers: makeHeaders(
        { "Content-Type": "application/json", ...extraHeaders },
        cookies
      ),
      body: JSON.stringify(data),
    });
  }

  return { get, post };
}
