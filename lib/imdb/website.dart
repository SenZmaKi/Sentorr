/// Public headers observed on IMDb's live homepage. No browser cookies,
/// account credentials, or session identifiers are included.
const imdbWebsiteHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/154.0.0.0 Safari/537.36',
  'Accept': 'application/graphql+json, application/json',
  'Content-Type': 'application/json',
  'Origin': 'https://www.imdb.com',
  'Referer': 'https://www.imdb.com/',
  'x-imdb-client-name': 'imdb-web-next-localized',
  'x-imdb-user-country': 'US',
  'x-imdb-user-language': 'en-US',
};

const imdbGraphqlUrl = 'https://api.graphql.imdb.com/';

/// Captured from IMDb's own homepage request on 2026-10-02.
const imdbHomepageHash =
    'f6ccf12469ab9e9f3faed4718a6c0c447065d8db21afe7ce18f05488424c3bd1';
