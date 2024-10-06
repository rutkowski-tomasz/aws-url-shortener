import { baseUrl, login, shortenUrl } from './shared.js';
import http from 'k6/http';
import { sleep, check } from 'k6';
import exec from 'k6/execution';

export const options = {
    vus: 1,
    maxRedirects: 0,
    stages: [
        { duration: '1h', target: 20_000 },
    ],
};

export function setup() {
    const token = login();
    const code = shortenUrl(token);
    return { code };
}

export default function (data) {
    const res = http.get(`${baseUrl}/get-url?code=${data.code}`);
    const checks = check(res, {
        'status is 302': () => res.status === 302,
        'duration is less than 2000ms': () => res.timings.duration < 2000
    });

    if (!checks) {
        console.log(`VUs active: ${exec.instance.vusActive}, Iterations completed: ${exec.instance.iterationsCompleted}`);
        exec.test.abort();
    }

    sleep(1);
}
