const axios = require('axios');

const urlShortenerBaseUrl = 'https://5fx9tfed9e.execute-api.eu-central-1.amazonaws.com/dev';

describe('Lambda function integration', () => {
  let code;
  const longUrl = 'https://example.com';

  test('shorten-url-lambda creates a short code for a URL', async () => {
    const response = await axios.post(`${urlShortenerBaseUrl}/shorten-url`, { longUrl });
    expect(response.status).toBe(200);
    expect(response.data.result).toHaveProperty('code');
    code = response.data.result.code;
  });                                 

  test('get-url-lambda redirects to the original URL using the short code', async () => {
    const response = await axios.get(`${urlShortenerBaseUrl}/get-url?code=${code}`, {
      validateStatus: () => true,
      maxRedirects: 0
    });
    expect(response.status).toBe(302);
    expect(response.headers.location).toBe(longUrl);
  });
});
