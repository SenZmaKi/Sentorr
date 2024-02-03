class Client {
    private headers: HeadersInit;
    private static userAgents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    ];
    constructor() {
        // const random_idx = Math.floor(Math.random() * Client.userAgents.length);
        // this.headers = { "User-Agent": Client.userAgents[random_idx] };
        this.headers = {};

    }
    public async get(url: string, headers: HeadersInit | undefined = undefined, cookies: string[] = []): Promise<Response> {
        const strCookies = cookies.join(";");
        headers = { ...headers, ...this.headers, "Cookie": strCookies };
        return fetch(url, { method: "GET", headers: headers });
    }
}

const CLIENT = new Client();

export { CLIENT };