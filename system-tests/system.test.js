const axios = require('axios');
const WebSocket = require('ws');

let config = {
  urlShortenerBaseUrl: 'https://35o6amojr1.execute-api.eu-central-1.amazonaws.com/dev',
  cognitoUrl: 'https://cognito-idp.eu-central-1.amazonaws.com',
  clientId: '5fnqfaub5lgsg36oukp82at78g',
  username: 'system-tests@example.com',
  password: 'SecurePassword123!',
  webSocketApiUrl: 'wss://5si3qer1q4.execute-api.eu-central-1.amazonaws.com/dev',
  webSocketTimeout: 30000,
};

if (process.env.environment == 'prd')
{
  config.urlShortenerBaseUrl = 'https://11428gw63m.execute-api.eu-central-1.amazonaws.com/prd';
  config.clientId = '1chdujtpbetje7g3jine9cgdmg';
}

describe('Lambda function integration', () => {
  let code;
  let idToken;
  const longUrl = 'https://github.com/rutkowski-tomasz/ExpenseSplitter.Api';

  beforeAll(async () => {
    async function fetchCognitoToken() {
      try {
        const response = await axios.post(config.cognitoUrl, {
          "AuthFlow": "USER_PASSWORD_AUTH",
          "ClientId": config.clientId,
          "AuthParameters": {
            "USERNAME": config.username,
            "PASSWORD": config.password
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
    const response = await axios.post(`${config.urlShortenerBaseUrl}/shorten-url`, { longUrl }, {
      headers: {
        'Authorization': `Bearer ${idToken}`
      }
    });
    expect(response.status).toBe(200);
    expect(response.data.result).toHaveProperty('code');
    code = response.data.result.code;

    console.log('Shortened URL code: ', code);
  });

  test('get-url-lambda redirects to the original URL using the short code', async () => {
    const response = await axios.get(`${config.urlShortenerBaseUrl}/get-url?code=${code}`, {
      validateStatus: () => true,
      maxRedirects: 0
    });
    expect(response.status).toBe(302);
    expect(response.headers.location).toBe(longUrl);
  });

  test('get-preview-url-lambda returns preview URLs', async () => {
    const response = await axios.get(`${config.urlShortenerBaseUrl}/get-preview-url?code=${code}`);
    expect(response.status).toBe(200);
    expect(response.data.result).toHaveProperty('desktopPreview');
    expect(response.data.result).toHaveProperty('mobilePreview');
  });

  test('get-my-urls integrates with DynamoDB', async () => {
    const response = await axios.get(`${config.urlShortenerBaseUrl}/get-my-urls`, {
      headers: {
        'Authorization': `Bearer ${idToken}`
      }
    });
    expect(response.status).toBe(200);
    expect(response.data).toHaveProperty('links');
    expect(response.data.links.length).toBeGreaterThan(0);
    const link = response.data.links.find(l => l.code === code);
    expect(link).toBeDefined();
    expect(link).toHaveProperty('code', code);
    expect(link).toHaveProperty('longUrl', longUrl);
    expect(link).toHaveProperty('createdAt');
  });

  describe('PREVIEW_GENERATED event is pushed', () => {
    let ws;
    beforeAll(() => {
      ws = new WebSocket(config.webSocketApiUrl, {
        headers: {
          'Authorization': `Bearer ${idToken}`
        }
      });
    });

    test('connects to WebSocket and receives PREVIEW_GENERATED event', async () => {

      await new Promise((resolve, reject) => {
        ws.on('message', (data) => {
          const payload = JSON.parse(data);
          console.log('Received payload: %j', payload);
          if (payload.eventType === 'PREVIEW_GENERATED' && payload.code === code) {
            resolve(payload);
          }
        });

        ws.on('error', reject);
      });

    }, config.webSocketTimeout);

    afterAll(() => {
      ws.close();
    });
  });

});
