export class Client {
  private headers: HeadersInit;
  private static userAgents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
  ];
  constructor() {
    const random_idx = Math.floor(Math.random() * Client.userAgents.length);
    this.headers = { "User-Agent": Client.userAgents[random_idx] };
    //    this.headers = {};
  }

  makeHeaders(
    headers: HeadersInit | undefined = undefined,
    cookies: string[] | undefined = undefined,
  ) {
    const finalHeaders = {
      ...headers,
      ...this.headers,
      Cookie: cookies ? cookies.join("; ") : "",
    };
    return finalHeaders;
  }
  public async get(
    url: string,
    headers: HeadersInit | undefined = undefined,
    cookies: string[] | undefined = undefined,
  ): Promise<Response> {
    headers = this.makeHeaders(headers, cookies);
    return fetch(url, { method: "GET", headers: headers });
  }

  public async post(
    url: string,
    data: any,
    headers: HeadersInit | undefined = undefined,
    cookies: string[] | undefined = undefined,
  ): Promise<Response> {
    headers = headers ?? {};
    headers["Content-Type"] = "application/json";
    headers = this.makeHeaders(headers, cookies);
    const body = JSON.stringify(data);
    return fetch(url, { method: "POST", headers, body });
  }
}
