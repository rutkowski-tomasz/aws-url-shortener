const axios = require('axios');

const urlShortenerBaseUrl = 'https://d0ghygtws1.execute-api.eu-central-1.amazonaws.com/dev';
const cognitoUrl = 'https://cognito-idp.eu-central-1.amazonaws.com';

const clientId = '4np6oaiu11oom6khgturukdfus';
const username = 'system-tests@example.com';
const password = 'Password123!';

describe('Lambda function integration', () => {
  let code;
  let idToken;
  const longUrl = 'https://example.com';

  beforeAll(async () => {
    async function fetchCognitoToken() {
      try {
        const response = await axios.post(cognitoUrl, {
          "AuthFlow": "USER_PASSWORD_AUTH",
          "ClientId": clientId,
          "AuthParameters": {
            "USERNAME": username,
            "PASSWORD": password
          }
        }, {
          headers: {
            'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
            'Content-Type': 'application/x-amz-json-1.1'
          }
        });
        return response.data.AuthenticationResult.IdToken;
      } catch (error) {
        console.error('Error fetching Cognito token:', error);
        throw error;
      }
    }

    idToken = await fetchCognitoToken();
  });

  test('shorten-url-lambda creates a short code for a URL', async () => {
    const response = await axios.post(`${urlShortenerBaseUrl}/shorten-url`, { longUrl }, {
      headers: {
        'Authorization': `Bearer ${idToken}`
      }
    });
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
