const API_BASE_URL = 'https://35o6amojr1.execute-api.eu-central-1.amazonaws.com/dev';
const COGNITO_URL = 'https://cognito-idp.eu-central-1.amazonaws.com';
const CLIENT_ID = '5fnqfaub5lgsg36oukp82at78g';

let idToken = localStorage.getItem('idToken');
let refreshToken = localStorage.getItem('refreshToken');

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
    } else {
        showLoggedOutState();
    }
});

function clearTokens() {
    localStorage.removeItem('idToken');
    localStorage.removeItem('refreshToken');
    idToken = null;
    refreshToken = null;
}

async function refreshIdToken() {
    try {
        const response = await fetch(COGNITO_URL, {
            method: 'POST',
            headers: {
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
                'Content-Type': 'application/x-amz-json-1.1'
            },
            body: JSON.stringify({
                ClientId: CLIENT_ID,
                AuthFlow: 'REFRESH_TOKEN_AUTH',
                AuthParameters: {
                    REFRESH_TOKEN: refreshToken
                }
            })
        });
        const data = await response.json();
        idToken = data.AuthenticationResult.IdToken;
        localStorage.setItem('idToken', idToken);
        return idToken;
    } catch (error) {
        console.error('Error refreshing token:', error);
        clearTokens();
        showLoggedOutState();
        throw error;
    }
}

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
        refreshToken = data.AuthenticationResult.RefreshToken;
        localStorage.setItem('idToken', idToken);
        localStorage.setItem('refreshToken', refreshToken);
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
}

function showLoggedOutState() {
    authSection.classList.remove('hidden');
    urlShortenerSection.classList.add('hidden');
    myUrlsSection.classList.add('hidden');
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
        resultDiv.innerHTML = `Short URL: <a href="${API_BASE_URL}/get-url?code=${data.code}" target="_blank" class="text-blue-500">${API_BASE_URL}/get-url?code=${data.code}</a>`;
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

        if (response.status === 401) {
            await refreshIdToken();
            return getMyUrls();
        }

        const data = await response.json();
        myUrlsList.innerHTML = '';
        data.links.forEach(link => {
            const li = document.createElement('li');
            li.className = 'mb-2';
            li.dataset.code = link.code;
            li.innerHTML = `
                <a href="${API_BASE_URL}/get-url?code=${link.code}" target="_blank" class="text-blue-500">${link.code}</a>
                <span class="ml-2 text-gray-600">${link.longUrl}</span>
            `;
            myUrlsList.appendChild(li);
            getPreviewUrls(link.code);
        });
    } catch (error) {
        console.error('Error fetching URLs:', error);
        if (error.response && error.response.status === 401) {
            clearTokens();
            showLoggedOutState();
        }
    }
}

async function getPreviewUrls(code) {
    try {
        const response = await fetch(`${API_BASE_URL}/get-preview-url?code=${code}`, {
            headers: {
                'Authorization': `Bearer ${idToken}`
            }
        });
        const data = await response.json();
        if (data.isSuccess) {
            updatePreviewImages(code, data.result.desktopPreview, data.result.mobilePreview);
        }
    } catch (error) {
        console.error('Error fetching preview URLs:', error);
    }
}

function updatePreviewImages(code, desktopPreview, mobilePreview) {
    const linkElement = document.querySelector(`#my-urls-list li[data-code="${code}"]`);
    if (linkElement) {
        const previewContainer = linkElement.querySelector('.preview-container') || document.createElement('div');
        previewContainer.className = 'preview-container mt-2 flex space-x-2';
        previewContainer.innerHTML = `
            <img src="${desktopPreview}" alt="Desktop Preview" class="w-24 h-auto cursor-pointer" onclick="openImageDialog('${desktopPreview}')">
            <img src="${mobilePreview}" alt="Mobile Preview" class="w-12 h-auto cursor-pointer" onclick="openImageDialog('${mobilePreview}')">
        `;
        linkElement.appendChild(previewContainer);
    }
}

function openImageDialog(imageSrc) {
    const dialog = document.createElement('div');
    dialog.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
    dialog.innerHTML = `<img src="${imageSrc}" alt="Full size preview" class="max-w-full max-h-full">`;
    dialog.onclick = closeImageDialog;
    document.body.appendChild(dialog);
}

function closeImageDialog(event) {
    if (event.target === event.currentTarget) {
        event.target.remove();
    }
}
