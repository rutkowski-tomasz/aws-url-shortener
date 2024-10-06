import http from 'k6/http';
import { check } from 'k6';

export const baseUrl = 'https://35o6amojr1.execute-api.eu-central-1.amazonaws.com/dev';
const cognitoBaseUrl = 'https://cognito-idp.eu-central-1.amazonaws.com';
const cognitoClientId = '5fnqfaub5lgsg36oukp82at78g';

export function login() {
    const loginPayload = JSON.stringify({
        ClientId: cognitoClientId,
        AuthFlow: "USER_PASSWORD_AUTH",
        AuthParameters: {
            USERNAME: "system-tests@example.com",
            PASSWORD: "SecurePassword123!"
        }
    });

    const loginHeaders = {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth'
    };

    const loginResponse = http.post(cognitoBaseUrl, loginPayload, { headers: loginHeaders });
    check(loginResponse, { 'login successful': (r) => r.status === 200 });
    return loginResponse.json('AuthenticationResult.IdToken');
}

export function shortenUrl(token) {
    const shortenPayload = JSON.stringify({
        longUrl: "https://github.com/rutkowski-tomasz/aws-url-shortener"
    });

    const shortenHeaders = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
    };

    const shortenResponse = http.post(`${baseUrl}/shorten-url`, shortenPayload, { headers: shortenHeaders });
    check(shortenResponse, { 'shorten successful': (r) => r.status === 200 });
    return shortenResponse.json('code');
}