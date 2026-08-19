// secrets.js — resolve DB credentials from Secrets Manager at boot.
// The app calls this once at startup and caches in memory.
// AWS_ENDPOINT_URL points the SDK at LocalStack when set.
// There is no if(isLocalStack) branch — same code runs on real AWS.

'use strict';

const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require('@aws-sdk/client-secrets-manager');

let cached = null;

async function resolveDbCredentials() {
  if (cached) return cached;

  const secretArn = process.env.SECRET_ARN;
  if (!secretArn) throw new Error('SECRET_ARN environment variable is not set');

  const client = new SecretsManagerClient({
    region: process.env.AWS_DEFAULT_REGION || 'us-east-1',
    // AWS_ENDPOINT_URL is picked up automatically by the SDK v3
  });

  const response = await client.send(
    new GetSecretValueCommand({ SecretId: secretArn })
  );

  const secret = JSON.parse(response.SecretString);

  // Log ARN and version only — never the password value
  console.log(JSON.stringify({
    event: 'secret_resolved',
    arn: secretArn,
    version: response.VersionId,
    source: 'secretsmanager',
  }));

  cached = {
    host:     secret.host,
    port:     parseInt(secret.port, 10),
    user:     secret.username,
    password: secret.password,
    database: secret.dbname,
    ssl:      { rejectUnauthorized: false },
  };

  return cached;
}

module.exports = { resolveDbCredentials };
