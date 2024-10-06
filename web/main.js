const API_BASE_URL = 'https://35o6amojr1.execute-api.eu-central-1.amazonaws.com/dev';
const COGNITO_URL = 'https://cognito-idp.eu-central-1.amazonaws.com';
const CLIENT_ID = '5fnqfaub5lgsg36oukp82at78g';
const WS_URL = 'wss://5si3qer1q4.execute-api.eu-central-1.amazonaws.com/dev';

let idToken = localStorage.getItem('idToken');
let ws = null;

const loginBtn = document.getElementById('login-btn');
const shortenBtn = document.getElementById('shorten-btn');
const authSection = document.getElementById('auth-section');
const urlShortenerSection = document.getElementById('url-shortener-section');
const myUrlsSection = document.getElementById('my-urls-section');
const resultDiv = document.getElementById('result');
const myUrlsList = document.getElementById('my-urls-list');

loginBtn.addEventListener('click', login);
shortenBtn.addEventListener('click', shortenUrl);

document.addEventListener('DOMContentLoaded', () => {
    if (idToken) {
        showLoggedInState();
    }
});

async function login() {
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;

    try {
        const response = await fetch(COGNITO_URL, {
            method: 'POST',
            headers: {
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
                'Content-Type': 'application/x-amz-json-1.1'
            },
            body: JSON.stringify({
                ClientId: CLIENT_ID,
                AuthFlow: 'USER_PASSWORD_AUTH',
                AuthParameters: {
                    USERNAME: email,
                    PASSWORD: password
                }
            })
        });

        const data = await response.json();
        idToken = data.AuthenticationResult.IdToken;
        localStorage.setItem('idToken', idToken);
        showLoggedInState();
    } catch (error) {
        console.error('Login error:', error);
        alert('Login failed. Please check your credentials and try again.');
    }
}

function showLoggedInState() {
    authSection.classList.add('hidden');
    urlShortenerSection.classList.remove('hidden');
    myUrlsSection.classList.remove('hidden');
    getMyUrls();
    connectWebSocket();
}

async function shortenUrl() {
    const longUrl = document.getElementById('long-url').value;

    try {
        const response = await fetch(`${API_BASE_URL}/shorten-url`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${idToken}`
            },
            body: JSON.stringify({ longUrl })
        });

        const data = await response.json();
        resultDiv.innerHTML = `Short URL: <a href="${API_BASE_URL}/get-url?code=${data.result.code}" target="_blank" class="text-blue-500">${API_BASE_URL}/get-url?code=${data.result.code}</a>`;
        getMyUrls();
    } catch (error) {
        console.error('Error shortening URL:', error);
        alert('Failed to shorten URL. Please try again.');
    }
}

async function getMyUrls() {
    try {
        const response = await fetch(`${API_BASE_URL}/get-my-urls`, {
            headers: {
                'Authorization': `Bearer ${idToken}`
            }
        });

        const data = await response.json();
        myUrlsList.innerHTML = '';
        data.links.forEach(link => {
            const li = document.createElement('li');
            li.className = 'mb-2';
            li.innerHTML = `
                <a href="${API_BASE_URL}/get-url?code=${link.code}" target="_blank" class="text-blue-500">${API_BASE_URL}/get-url?code=${link.code}</a>
                <span class="ml-2 text-gray-600">${link.longUrl}</span>
            `;
            myUrlsList.appendChild(li);
        });
    } catch (error) {
        console.error('Error fetching URLs:', error);
    }
}

function connectWebSocket() {
    ws = new WebSocket(WS_URL);

    ws.onopen = () => {
        console.log('WebSocket connected');
        ws.send(JSON.stringify({ action: 'authorize', token: idToken }));
    };

    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.eventType === 'PREVIEW_GENERATED') {
            alert(`Preview generated for code: ${data.code}`);
            getMyUrls();
        }
    };

    ws.onclose = () => {
        console.log('WebSocket disconnected');
        setTimeout(connectWebSocket, 5000);
    };

    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
    };
}
