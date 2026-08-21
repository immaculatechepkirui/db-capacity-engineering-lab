
## Note on target verification
The 2201/2202/2203 k6 runs were executed against localhost:8080. A container
name collision was discovered afterward (app-live failed to bind that port,
meaning an unverified service answered instead). The load-shape and failure
patterns are consistent with the real app under stress, but the exact target
was not confirmed at the time. Re-run against a verified port before trusting
these numbers for grading-critical claims.
