// Test 3 - Throughput & tail latency (k6).
// Drives a constant load and lets k6 report RPS and p50/p95/p99 latency.
// Run with the same parameters against both services:
//   URL=http://hello.spinkube.local k6 run load_test.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    constant_load: {
      executor: 'constant-vus',
      vus: 50,
      duration: '60s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],            // < 1% errors
    http_req_duration: ['p(95)<200', 'p(99)<500'],
  },
};

export default function () {
  const res = http.get(`${__ENV.URL}/`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
