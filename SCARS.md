# SCARS — Regional Health On-Call Lab

## OPS-2201 — Patient search full table scan
- **S — Symptom:** p95 latency 7.49ms at baseline → 17,630ms under 200 VUs (1,782× degradation). Search unusable.
- **C — Cause:** No index on `patients.last_name`. MySQL performs a full table scan of 100,000 rows per request. Under 200 concurrent searchers: 20M row reads competing simultaneously.
- **A — Action:** `CREATE INDEX idx_patients_last_name ON patients(last_name);`
- **R — Result:** EXPLAIN changed from `type: ALL, rows: ~100000` to `type: ref, rows: ~handful`. p95 dropped from 17.6s to <300ms.
- **Scar / lesson:** Index design must be part of the schema review, not an afterthought. Any column in a WHERE clause on a table expected to grow beyond 10k rows needs an index or a documented reason it doesn't.
- **Evidence:** evidence/OPS-2201-before.txt, evidence/OPS-2201-after.txt

## OPS-2202 — Connection pool exhaustion at surge
- **S — Symptom:** At 2,000 VUs, successful RPS collapsed, p95 hit seconds, DB CPU stayed flat.
- **C — Cause:** MySQL connection pool too small (default typically 5-10). 2,000 concurrent requests queued waiting for one of the few available connections. DB idle because it never received the requests.
- **A — Action:** Increased `connectionLimit` in MySQL pool config to 50. Restarted API.
- **R — Result:** RPS recovered, error rate dropped, DB CPU rose proportionally (proving it was now receiving work).
- **Scar / lesson:** Pool size must be sized to throughput: pool ≥ λ × W (Little's Law). Alert on connection wait queue depth, not just DB CPU.
- **Evidence:** evidence/OPS-2202-before.txt, evidence/OPS-2202-after.txt

## OPS-2203 — Row lock serialization on hot hospital row
- **S — Symptom:** 500 VUs admitting to hospital 1 — admissions failed with DB errors, throughput collapsed.
- **C — Cause:** Read-check-write pattern inside a transaction held an exclusive row lock on hospitals.id=1 for the full transaction duration. Max throughput = 1/W. More concurrency did not help — it only increased waiters and timeouts.
- **A — Action:** Replaced read-check-write with atomic UPDATE hospitals SET current_admissions = current_admissions + 1 WHERE id = ? AND current_admissions < capacity.
- **R — Result:** Lock hold time reduced to microseconds. Throughput increased, error rate dropped.
- **Scar / lesson:** Any pattern that reads then writes a shared row under a transaction will serialize all writers. Atomic conditional updates eliminate the critical section. Alert on InnoDB lock wait timeouts.
- **Evidence:** evidence/OPS-2203-before.txt, evidence/OPS-2203-after.txt

## OPS-2204 — O(N) memory export OOM crash
- **S — Symptom:** Container restarted repeatedly during export run. Memory spiked to 160MB limit before each crash. Other users affected during crash window.
- **C — Cause:** Export loaded all 100,000 rows into Node.js heap simultaneously. ~500 bytes/row × 100,000 = ~50MB per caller. 50 concurrent callers × 50MB = 2,500MB required vs 160MB container limit. OOM killer restarted the process.
- **A — Action:** Replaced bulk findAll() with paginated streaming — write 1,000 rows at a time to the response stream, never holding more than one page in memory.
- **R — Result:** Peak heap stayed bounded regardless of dataset size. No restarts. Other endpoints unaffected.
- **Scar / lesson:** Any endpoint that returns unbounded data must stream. Alert on nodejs_heap_size_used_bytes approaching 80% of container memory limit.
- **Evidence:** evidence/OPS-2204-before.txt, evidence/OPS-2204-after.txt
