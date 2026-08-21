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

## Docker VM Manager did not register a custom-built image as an AMI
- **What LocalStack did:** LocalStack's own bundled AMI (`ami-df5de72bdb3b`) launched
  successfully via `RunInstances` — confirming Docker VM Manager itself works. However,
  a custom image built locally and tagged per the documented scheme
  (`localstack-ec2/app:ami-<sha12>`) was never returned by `DescribeImages` when
  filtered on `tag:ec2_vm_manager=docker`, and `RunInstances` against it failed with
  "collecting instance settings: couldn't find resource."
- **How I detected it:** isolated the variable by testing LocalStack's own bundled
  AMI first (success), then retesting the custom-tagged image (failure) — same
  LocalStack container, same Docker socket, same host. Confirmed the Docker socket
  was correctly mounted and the image existed via `docker images`.
- **What I'd verify on real AWS:** none of this applies — real EC2 has no local
  image-registration step at all. This is purely a LocalStack Docker VM Manager
  fidelity gap specific to custom-built (vs. pre-pulled) images. Worked around it
  by running the same Docker image directly (not via Terraform-managed EC2) for
  C3/C4/C7 evidence, wired to the same real Secrets Manager secret and Aiven DB.
