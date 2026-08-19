# FIDELITY.md — Where LocalStack differed from real AWS

## 1. Security groups apply only at instance creation
SG rules apply only when the instance launches. Changing a SG after launch
opens no ports on the running instance.
Detection: added a rule post-launch, port remained blocked.
Real AWS verification: SG changes propagate within seconds on live traffic.

## 2. Custom SGs do not filter traffic at runtime
Only the default SG is enforced. Custom SGs are stored by the API but
traffic is not actually filtered by them.
Detection: port was reachable despite no ingress rule.
Real AWS verification: verify custom SG blocks traffic as declared.

## 3. IMDS has no IAM credentials endpoint
`/latest/meta-data/iam/security-credentials/` returns nothing.
Instance-profile credentials cannot be demonstrated — static test
credentials are used instead (AWS_ACCESS_KEY_ID=test).
Real AWS verification: replace with instance profile, verify GetSecretValue
succeeds without hardcoded keys.

## 4. RDS storage_encrypted is stored but not applied
`storage_encrypted = true` is accepted by the API but no KMS encryption
is applied to the underlying MySQL container.
Real AWS verification: verify KMS key usage in CloudTrail.

## 5. Docker socket is shared inside EC2 instances
A `docker run` inside the instance creates a sibling on the host, not a
child container. On real EC2, Docker must be separately installed.

## 6. ELBv2 health checking is undocumented
ALB target group health checks are written as IaC and graded by trivy, but
LocalStack does not reliably implement active health checking or unhealthy
target removal. nginx carries real health routing in this lab.
Real AWS verification: verify ALB stops routing when /readyz returns 503.

## 7. RDS endpoint is localhost, not a resolvable hostname inside the instance
LocalStack returns `localhost:<port>` as the RDS endpoint. Inside the EC2
container, localhost resolves to the container itself. Must use
`localhost.localstack.cloud` which resolves to the Docker bridge IP.
Real AWS verification: verify endpoint DNS resolution inside the VPC subnet.
