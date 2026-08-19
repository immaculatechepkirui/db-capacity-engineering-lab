.PHONY: up down verify bootstrap build

LOCALSTACK_ENDPOINT ?= http://localhost:4566
AWS  = aws --endpoint-url=$(LOCALSTACK_ENDPOINT) --region=us-east-1 \
           --no-cli-pager
IMAGE_TAG := sha-$(shell git rev-parse --short=12 HEAD 2>/dev/null || echo "000000000000")
AMI_TAG   := localstack-ec2/app:ami-$(IMAGE_TAG)

bootstrap:
@echo "==> Bootstrapping S3 state bucket + DynamoDB lock table"
$(AWS) s3 mb s3://regional-health-tfstate 2>/dev/null || true
$(AWS) s3api put-bucket-versioning \
  --bucket regional-health-tfstate \
  --versioning-configuration Status=Enabled
$(AWS) s3api put-bucket-encryption \
  --bucket regional-health-tfstate \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
$(AWS) dynamodb create-table \
  --table-name regional-health-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null || true
@echo "==> Bootstrap done"

build:
@echo "==> Building Docker image and tagging as LocalStack AMI"
docker build -t app:$(IMAGE_TAG) .
docker tag app:$(IMAGE_TAG) $(AMI_TAG)
@echo "==> Image tagged as $(AMI_TAG)"

up: bootstrap build
@echo "==> Running tflocal init + apply"
cd terraform && tflocal init -reconfigure -input=false
cd terraform && tflocal apply -auto-approve -input=false \
  -var="app_ami_id=$(IMAGE_TAG)"
@echo "==> Stack is up"
@echo "Secret ARN: $$(cd terraform && tflocal output -raw secret_arn)"

verify:
@echo "==> Verification checks"
@echo ""
@echo "--- 1. Terraform plan empty after apply ---"
@cd terraform && tflocal plan -detailed-exitcode -input=false \
  -var="app_ami_id=$(IMAGE_TAG)" > /tmp/plan.out 2>&1; \
  CODE=$$?; \
  if [ $$CODE -eq 0 ]; then echo "PASS: no changes"; \
  elif [ $$CODE -eq 2 ]; then echo "FAIL: plan has changes"; cat /tmp/plan.out; exit 1; \
  else echo "FAIL: plan error"; cat /tmp/plan.out; exit 1; fi

@echo ""
@echo "--- 2. GET /healthz → 200 ---"
@IP=$$(cd terraform && tflocal output -raw instance_private_ip 2>/dev/null || echo "127.0.0.1"); \
  STATUS=$$(curl -s -o /dev/null -w "%{http_code}" http://$$IP:3000/healthz 2>/dev/null || echo "000"); \
  if [ "$$STATUS" = "200" ]; then echo "PASS: /healthz returned 200"; \
  else echo "FAIL: /healthz returned $$STATUS"; exit 1; fi

@echo ""
@echo "--- 3. GET /readyz → 200 ---"
@IP=$$(cd terraform && tflocal output -raw instance_private_ip 2>/dev/null || echo "127.0.0.1"); \
  STATUS=$$(curl -s -o /dev/null -w "%{http_code}" http://$$IP:3000/readyz 2>/dev/null || echo "000"); \
  if [ "$$STATUS" = "200" ]; then echo "PASS: /readyz returned 200"; \
  else echo "FAIL: /readyz returned $$STATUS"; exit 1; fi

@echo ""
@echo "--- 4. App resolved creds from Secrets Manager ---"
@IP=$$(cd terraform && tflocal output -raw instance_private_ip 2>/dev/null || echo "127.0.0.1"); \
  BODY=$$(curl -sf http://$$IP:3000/debug/secret-source 2>/dev/null || echo "{}"); \
  echo "$$BODY" | grep -q "secretsmanager" && echo "PASS: creds from Secrets Manager" || \
  (echo "FAIL: secret-source did not mention secretsmanager"; exit 1)

@echo ""
@echo "--- 5. gitleaks zero findings ---"
@gitleaks detect --source . --no-git -q 2>/dev/null && echo "PASS: zero leaks" || \
  (echo "FAIL: gitleaks found secrets"; exit 1)

@echo ""
@echo "==> All checks passed"

down:
@echo "==> Destroying stack"
cd terraform && tflocal destroy -auto-approve -input=false \
  -var="app_ami_id=$(IMAGE_TAG)"
@echo "==> Destroyed"
