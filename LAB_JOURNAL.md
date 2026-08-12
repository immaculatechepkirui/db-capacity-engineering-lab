# LAB JOURNAL — Regional Health DB Capacity Engineering Lab

## Baseline

### Setup

The database was seeded successfully with:

* **patients:** 100,000 rows
* **hospitals:** 5 rows

Seed command:

```bash
docker compose exec capacity-api bash /usr/local/bin/seed.sh
```

Result:

```text
MySQL is up.
Creating schema and loading 100000 patient rows...
seeded
patients rows: 100000
seeded
hospitals rows: 5
Seed complete.
```

### Baseline load test

Command:

```bash
k6 run load-tests/00-baseline.js
```

Results:

| Metric            |        Result |
| ----------------- | ------------: |
| VUs               |            50 |
| Duration          |           30s |
| HTTP requests     |         1,500 |
| Request rate      |   49.42 req/s |
| Average latency   |       9.09 ms |
| Median latency    |       2.74 ms |
| p90 latency       |       4.85 ms |
| p95 latency       |       7.49 ms |
| Maximum latency   |     239.52 ms |
| HTTP failure rate |         0.00% |
| Checks succeeded  | 1,500 / 1,500 |

Thresholds passed:

```text
p(95)<200ms: PASS
http_req_failed rate<0.01: PASS
```

Baseline establishes that the system performs normally at approximately 50 concurrent users.

---

# OPS-2201 — Patient Search Full Table Scan

## Hypothesis

The patient search endpoint performs a full table scan because `patients.last_name` does not have an index.

With 100,000 patient records, MySQL must scan the table for each search request.

## Investigation

Initial reproduction was performed using:

```bash
k6 run load-tests/reproduce-OPS-2201.js 2>&1 | tee evidence/OPS-2201-before.txt
```

The complete before-test output is stored in:

```text
evidence/OPS-2201-before.txt
```

## Fix

Created an index on `patients.last_name`:

```sql
CREATE INDEX idx_patients_last_name ON patients(last_name);
```

Command used:

```bash
docker compose exec mysql-db mysql -uroot -plabpassword capacity_lab -e "CREATE INDEX idx_patients_last_name ON patients(last_name);"
```

## Verification

Command:

```bash
docker compose exec mysql-db mysql -uroot -plabpassword capacity_lab -e "EXPLAIN SELECT * FROM patients WHERE last_name = 'Smith';"
```

Result after the index:

```text
type: ref
possible_keys: idx_patients_last_name
key: idx_patients_last_name
ref: const
rows: 10000
```

This confirms that MySQL is using the new index instead of performing an `ALL` table scan.

## After-test

Command:

```bash
k6 run load-tests/reproduce-OPS-2201.js 2>&1 | tee evidence/OPS-2201-after.txt
```

Evidence:

```text
evidence/OPS-2201-before.txt
evidence/OPS-2201-after.txt
```

### Result

The database query plan changed from an unindexed table scan to indexed lookup.

**Note:** The exact before/after k6 latency figures should be taken from the corresponding evidence files rather than estimated here.

---

# OPS-2202 — Connection Pool Exhaustion

## Hypothesis

The 2,000-VU registration surge exceeds the available database connection pool. Requests therefore spend time waiting for a database connection.

## Before Test

Command:

```bash
k6 run load-tests/reproduce-OPS-2202.js 2>&1 | tee evidence/OPS-2202-before.txt
```

### Actual before-test results

| Metric            |          Result |
| ----------------- | --------------: |
| Maximum VUs       |           2,000 |
| Duration          |             30s |
| HTTP requests     |          38,084 |
| Request rate      |  1,224.63 req/s |
| Average latency   |          1.47 s |
| Median latency    |          1.36 s |
| p90 latency       |          1.90 s |
| p95 latency       |          2.39 s |
| Maximum latency   |          4.93 s |
| HTTP failure rate |           0.00% |
| Checks            | 38,084 / 38,084 |

The test completed successfully from an HTTP status perspective, but latency was significantly higher than the baseline.

## Investigation

Attempts to locate the pool configuration using:

```bash
grep -r "pool\|connectionLimit\|max\|Pool" src/ --include="*.js" -n
```

and:

```bash
grep -rn "createPool\|createConnection\|mysql.create" src/ --include="*.js"
```

returned:

```text
grep: src/: No such file or directory
```

Therefore, the exact source location and original connection pool size were not confirmed during the timed investigation.

## Restart

The API was restarted:

```bash
docker compose restart capacity-api
sleep 5
```

## After Test

Command:

```bash
k6 run load-tests/reproduce-OPS-2202.js 2>&1 | tee evidence/OPS-2202-after.txt
```

Actual results:

| Metric            |          Result |
| ----------------- | --------------: |
| Maximum VUs       |           2,000 |
| Duration          |             30s |
| HTTP requests     |          37,466 |
| Request rate      |  1,203.29 req/s |
| Average latency   |          1.49 s |
| Median latency    |          1.37 s |
| p90 latency       |          1.99 s |
| p95 latency       |          2.53 s |
| Maximum latency   |          5.92 s |
| HTTP failure rate |           0.00% |
| Checks            | 37,466 / 37,466 |

### Result

The restart alone did not demonstrate an improvement. The intended connection-pool configuration change to `connectionLimit: 50` was not verified because the application source directory could not be located during the investigation.

Evidence:

```text
evidence/OPS-2202-before.txt
evidence/OPS-2202-after.txt
```

---

# OPS-2203 — Row Lock Contention

## Hypothesis

All 500 concurrent admission requests target `hospital_id = 1`, causing row-level lock contention.

The read-check-write transaction serializes access to the same hospital row.

## Reproduction

Command:

```bash
k6 run load-tests/reproduce-OPS-2203.js 2>&1 | tee evidence/OPS-2203-before.txt
```

## Lock investigation

During the test, InnoDB showed the same hospital row being locked by multiple transactions.

Relevant evidence:

```text
OBJECT_NAME: hospitals
INDEX_NAME: PRIMARY
LOCK_TYPE: RECORD
LOCK_MODE: X,REC_NOT_GAP
LOCK_STATUS: GRANTED
LOCK_DATA: 1
```

Another transaction was waiting for the same row:

```text
OBJECT_NAME: hospitals
INDEX_NAME: PRIMARY
LOCK_TYPE: RECORD
LOCK_MODE: X,REC_NOT_GAP
LOCK_STATUS: WAITING
LOCK_DATA: 1
```

This directly demonstrates contention on `hospitals.id = 1`.

## Before-test results

| Metric                 |     Result |
| ---------------------- | ---------: |
| Maximum VUs            |        500 |
| Duration               |        30s |
| HTTP requests          |        118 |
| Request rate           | 1.97 req/s |
| Average latency        |    30.15 s |
| Median latency         |    30.14 s |
| p90 latency            |    53.84 s |
| p95 latency            |    56.81 s |
| Maximum latency        |    59.77 s |
| HTTP failure rate      |      0.00% |
| Interrupted iterations |        441 |

Threshold:

```text
p(95)<1000ms: FAILED
Actual p95: 56.81s
```

## Result

The test clearly reproduced severe row-lock serialization.

The observed lock state confirms that concurrent transactions were waiting for an exclusive lock on the same hospital row.

Evidence:

```text
evidence/OPS-2203-before.txt
```

The after-test was not completed during the initial deadline window.

---

# OPS-2204 — Export Memory Pressure / OOM

## Hypothesis

The export endpoint loads all 100,000 patient records into memory simultaneously.

With concurrent exports, memory usage can grow rapidly and exceed the container's memory limit.

## Intended investigation

The planned commands were:

```bash
docker stats db-capacity-engineering-lab-capacity-api-1 --no-stream
```

and:

```bash
k6 run load-tests/reproduce-OPS-2204.js 2>&1 | tee evidence/OPS-2204-before.txt
```

The export implementation was to be investigated with:

```bash
grep -rn "export\|patients/export" src/ --include="*.js" -n
```

## Intended fix

Replace a bulk operation such as:

```javascript
const patients = await Patient.findAll();
res.json(patients);
```

with paginated/streamed output so that the application does not hold the entire dataset in memory.

## Status

OPS-2204 investigation and after-test were not completed during the initial deadline window.

Evidence files should be added once the test is completed:

```text
evidence/OPS-2204-before.txt
evidence/OPS-2204-after.txt
```

---

# Summary

| Incident | Reproduced | Evidence              | Fix verified                          |
| -------- | ---------- | --------------------- | ------------------------------------- |
| OPS-2201 | Yes        | Before/after evidence | Index verified with EXPLAIN           |
| OPS-2202 | Yes        | Before/after evidence | No — pool configuration not confirmed |
| OPS-2203 | Yes        | Before evidence       | No — after-test not completed         |
| OPS-2204 | Pending    | Pending               | Pending                               |

## Key Findings

### OPS-2201

The `last_name` search initially required a full table scan. Adding:

```sql
CREATE INDEX idx_patients_last_name ON patients(last_name);
```

changed the query plan to use the index.

### OPS-2202

The 2,000-VU surge produced approximately 1,200 req/s but with approximately 1.5–2.5 seconds of latency at the main percentiles. The intended pool-size investigation was not completed because the expected `src/` directory was not present at the repository root.

### OPS-2203

The strongest confirmed incident finding. InnoDB showed an exclusive lock on `hospitals.id = 1` with another transaction waiting for the same row. At 500 VUs, p95 latency reached **56.81 seconds** and only **118 requests** completed during the test window.

### OPS-2204

The memory/OOM investigation remains incomplete.

---

# Evidence Directory

Current evidence collected:

```text
evidence/baseline-k6.txt
evidence/baseline-compose-ps.txt
evidence/baseline-docker-stats.txt

evidence/OPS-2201-before.txt
evidence/OPS-2201-after.txt
evidence/OPS-2201-compose-ps.txt
evidence/OPS-2201-docker-stats.txt
evidence/OPS-2201-reproduction.txt

evidence/OPS-2202-before.txt
evidence/OPS-2202-after.txt

evidence/OPS-2203-before.txt
```

Additional OPS-2204 evidence can be added after the investigation is completed.
