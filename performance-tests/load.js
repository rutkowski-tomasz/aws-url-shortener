import { baseUrl, login, shortenUrl } from './shared.js';
import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
    vus: 10,
    duration: '10s',
    maxRedirects: 0,
    thresholds: {
        http_req_failed: ['rate<=0.02'],
        http_req_duration: ['p(95)<1000']
    }
};

export function setup() {
    const token = login();
    const code = shortenUrl(token);
    return { code };
}

export default function (data) {
    const res = http.get(`${baseUrl}/get-url?code=${data.code}`);
    check(res, {
        'status is 302': () => res.status === 302,
        'duration is less than 2000ms': () => res.timings.duration < 2000
    });
    sleep(1);
}