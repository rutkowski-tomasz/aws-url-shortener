import { baseUrl, login, shortenUrl } from './shared.js';
import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
    vus: 10,
    maxRedirects: 0,
    thresholds: {
        http_req_failed: ['rate<0.01'],
        http_req_duration: ['p(95)<1000']
    },
    stages: [
        { duration: '1s', target: 100 },
        { duration: '10s', target: 2_000 },
        { duration: '1s', target: 2_000 },
        { duration: '10s', target: 100 },
        { duration: '1s', target: 0 },
    ]
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