# Database Configuration

This directory contains database initialization scripts for Elephant.

## init.sql

**Purpose:** PostgreSQL initialization script that runs when the database container first starts.

**When it runs:** BEFORE any service migrations, during PostgreSQL container initialization.

**What it does:**
- Creates PostgreSQL extensions (uuid-ossp, pgcrypto, pg_stat_statements)
- Creates database roles (elephant_app, elephant_reporting)
- Sets up default privileges for future tables
- Grants monitoring privileges

**What it does NOT do:**
- Create tables (handled by service migrations)
- Create views (handled by service migrations)
- Insert data (handled by service migrations)

**Why this separation?**

The init.sql script runs in the PostgreSQL `docker-entrypoint-initdb.d` directory, which executes BEFORE the Elephant services start. At this point:
- No tables exist yet
- No schemas are defined
- Services haven't run their migrations

Therefore, init.sql only sets up:
1. Extensions that services might need
2. Roles for application and reporting access
3. Default privileges for security

All actual schema creation (tables, indexes, views) is handled by service migrations:
- elephant-repository: Uses MIGRATE_DB=true
- elephant-user: Uses MIGRATE_DB=true
- elephant-index: Uses init container with migration SQL

## Usage

The init.sql file is automatically mounted in docker-compose files:

```yaml
postgres:
  image: postgres:16-alpine
  volumes:
    - postgres_data:/var/lib/postgresql/data
    - ../configs/database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
```

**Note:** This script only runs when the database is first created. If you modify it, you need to:

```bash
# Remove the volume to trigger re-initialization
docker compose -f docker-compose/docker-compose.core.yml down -v
docker compose -f docker-compose/docker-compose.core.yml up -d
```

## Security Notes

**Default passwords in init.sql are for development only!**

For production:
1. Change the passwords in init.sql
2. Or better: Create roles via environment variables or secrets
3. Use strong passwords and rotate them regularly

Example production setup:

```sql
CREATE ROLE elephant_app WITH LOGIN PASSWORD 'use-a-strong-password-here';
CREATE ROLE elephant_reporting WITH LOGIN PASSWORD 'use-another-strong-password';
```

## Password Rotation

Regular password rotation is a security best practice. Here's how to rotate database passwords for Elephant services.

### Scenario: Rotating elephant_app Password

**Goal:** Change the password for `elephant_app` role without downtime.

**Prerequisites:**
- Access to PostgreSQL as superuser
- Access to update service configurations (environment variables or secrets)
- Ability to restart services

#### Step 1: Generate New Password

```bash
# Generate a strong random password
NEW_PASSWORD=$(openssl rand -base64 32)
echo "New password: $NEW_PASSWORD"

# Save it securely (e.g., to a password manager or secrets vault)
```

#### Step 2: Update PostgreSQL Role

```bash
# Connect to PostgreSQL
docker exec -it elephant-postgres-1 psql -U postgres -d elephant

# Or if running outside Docker
psql -U postgres -d elephant
```

```sql
-- Change the password
ALTER ROLE elephant_app WITH PASSWORD 'new-strong-password-here';

-- Verify the role exists and can login
SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname = 'elephant_app';
```

#### Step 3: Update Service Configurations

**Option A: Environment Variables (Development/Docker Compose)**

Update your `.env` file or docker-compose environment:

```env
# .env file
DB_USER=elephant_app
DB_PASSWORD=new-strong-password-here
```

Then restart services:

```bash
cd elephant-handbook/docker-compose

# Restart all services that use the database
docker compose -f docker-compose.core.yml restart repository index user

# If using spell service
docker compose -f docker-compose.spell.yml restart spell
```

**Option B: Kubernetes Secrets (Production)**

```bash
# Create new secret
kubectl create secret generic elephant-db-credentials \
  --from-literal=username=elephant_app \
  --from-literal=password=new-strong-password-here \
  --namespace=elephant \
  --dry-run=client -o yaml | kubectl apply -f -

# Rolling restart of deployments
kubectl rollout restart deployment/elephant-repository -n elephant
kubectl rollout restart deployment/elephant-index -n elephant
kubectl rollout restart deployment/elephant-user -n elephant
kubectl rollout restart deployment/elephant-spell -n elephant

# Monitor rollout status
kubectl rollout status deployment/elephant-repository -n elephant
```

**Option C: AWS Secrets Manager (Production)**

```bash
# Update secret in AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id elephant/database/app-credentials \
  --secret-string '{"username":"elephant_app","password":"new-strong-password-here"}'

# Trigger service restart (depends on your deployment method)
# ECS: Update task definition and force new deployment
# EKS: Use external-secrets operator to sync and restart pods
```

### AWS Automatic Password Rotation

AWS Secrets Manager can automatically rotate database passwords on a schedule. This is the recommended approach for production.

#### Setup Automatic Rotation for RDS PostgreSQL

**Step 1: Store Database Credentials in Secrets Manager**

```bash
# Create secret with initial credentials
aws secretsmanager create-secret \
  --name elephant/database/app-credentials \
  --description "Elephant application database credentials" \
  --secret-string '{
    "engine": "postgres",
    "host": "elephant-db.cluster-xxxxx.us-east-1.rds.amazonaws.com",
    "port": 5432,
    "dbname": "elephant",
    "username": "elephant_app",
    "password": "initial-password-here"
  }'
```

**Step 2: Enable Automatic Rotation**

```bash
# Enable rotation with AWS managed Lambda function
aws secretsmanager rotate-secret \
  --secret-id elephant/database/app-credentials \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRDSPostgreSQLRotationSingleUser \
  --rotation-rules AutomaticallyAfterDays=30
```

**Step 3: Configure Services to Use Secrets Manager**

**For ECS Tasks:**

```json
{
  "containerDefinitions": [
    {
      "name": "elephant-repository",
      "image": "elephant-repository:latest",
      "secrets": [
        {
          "name": "DB_HOST",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:elephant/database/app-credentials:host::"
        },
        {
          "name": "DB_USER",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:elephant/database/app-credentials:username::"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:elephant/database/app-credentials:password::"
        },
        {
          "name": "DB_NAME",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:elephant/database/app-credentials:dbname::"
        }
      ]
    }
  ]
}
```

**For EKS with External Secrets Operator:**

```yaml
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Create SecretStore
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: elephant
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

---
# Create ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: elephant-db-credentials
  namespace: elephant
spec:
  refreshInterval: 1h  # Sync every hour
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: elephant-db-credentials
    creationPolicy: Owner
  data:
    - secretKey: DB_HOST
      remoteRef:
        key: elephant/database/app-credentials
        property: host
    - secretKey: DB_USER
      remoteRef:
        key: elephant/database/app-credentials
        property: username
    - secretKey: DB_PASSWORD
      remoteRef:
        key: elephant/database/app-credentials
        property: password
    - secretKey: DB_NAME
      remoteRef:
        key: elephant/database/app-credentials
        property: dbname

---
# Use in Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elephant-repository
  namespace: elephant
spec:
  template:
    spec:
      containers:
      - name: repository
        image: elephant-repository:latest
        envFrom:
        - secretRef:
            name: elephant-db-credentials  # Auto-synced from Secrets Manager
```

**Step 4: Grant IAM Permissions**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:elephant/database/*"
    }
  ]
}
```

**For ECS:** Attach to task execution role  
**For EKS:** Attach to service account via IRSA (IAM Roles for Service Accounts)

#### How AWS Automatic Rotation Works

AWS Secrets Manager uses a **four-phase rotation process** that ensures the new password works before completing the rotation. This is similar to a blue/green deployment strategy.

**The Four Phases:**

1. **createSecret Phase (Blue/Green Setup)**
   - Lambda generates a new random password
   - Creates a "pending" version of the secret with the new password
   - The current version (AWSCURRENT) remains unchanged
   - Both old and new passwords exist simultaneously

2. **setSecret Phase (Update Database)**
   - Lambda connects to PostgreSQL using the current (old) password
   - Updates the database role with the new password
   - For alternating user strategy: Creates a new user instead
   - If this fails, rotation stops and rolls back

3. **testSecret Phase (Verification - Critical!)**
   - Lambda attempts to connect to PostgreSQL using the NEW password
   - Runs test queries to verify the connection works
   - Checks that the user has the correct permissions
   - **If verification fails, rotation is aborted and rolled back**
   - This is the "green" environment test

4. **finishSecret Phase (Promote New Password)**
   - Only runs if testSecret succeeds
   - Moves the AWSCURRENT label to the new version
   - Old version is labeled AWSPREVIOUS (kept for rollback)
   - Services start using the new password on next secret fetch
   - Old password remains valid for a grace period

**Visual Flow:**

```
Before Rotation:
┌─────────────────────────────────────┐
│ Secret Version: v1                  │
│ Label: AWSCURRENT                   │
│ Password: old-password              │
│ Status: ✓ Active                    │
└─────────────────────────────────────┘

Phase 1 - createSecret:
┌─────────────────────────────────────┐
│ Secret Version: v1                  │
│ Label: AWSCURRENT                   │
│ Password: old-password              │
│ Status: ✓ Active                    │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ Secret Version: v2                  │
│ Label: AWSPENDING                   │
│ Password: new-password              │
│ Status: ⏳ Pending                   │
└─────────────────────────────────────┘

Phase 2 - setSecret:
PostgreSQL: ALTER ROLE elephant_app WITH PASSWORD 'new-password';

Phase 3 - testSecret (VERIFICATION):
┌─────────────────────────────────────┐
│ Test Connection:                    │
│ psql -U elephant_app                │
│      -h db.example.com              │
│      -d elephant                    │
│ Password: new-password              │
│                                     │
│ ✓ Connection successful             │
│ ✓ SELECT 1 works                    │
│ ✓ Permissions verified              │
└─────────────────────────────────────┘

Phase 4 - finishSecret (PROMOTION):
┌─────────────────────────────────────┐
│ Secret Version: v1                  │
│ Label: AWSPREVIOUS                  │
│ Password: old-password              │
│ Status: ⚠️  Deprecated               │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ Secret Version: v2                  │
│ Label: AWSCURRENT                   │
│ Password: new-password              │
│ Status: ✓ Active                    │
└─────────────────────────────────────┘
```

**Rollback on Failure:**

If testSecret fails (new password doesn't work):
- AWSCURRENT label stays on the old version
- AWSPENDING version is discarded
- Services continue using the old password
- CloudWatch alarm triggers
- No service disruption occurs

**Key Benefits:**
- Zero-downtime rotation
- Automatic verification before promotion
- Automatic rollback if verification fails
- Services automatically pick up new password on next connection or refresh
- Old password remains valid for a grace period (configurable)
- Audit trail in CloudTrail

**Grace Period:**

After rotation completes, both passwords work for a configurable period:
- Default: Old password valid for 24 hours after rotation
- Allows services with cached connections to continue working
- Gives time for all services to pick up the new password
- After grace period, old password is invalidated

**Example Lambda Test Code:**

```python
# testSecret phase in rotation Lambda
def test_secret(service_client, arn, token):
    """Verify the new password works"""
    
    # Get the pending secret
    metadata = service_client.get_secret_value(
        SecretId=arn, 
        VersionId=token, 
        VersionStage="AWSPENDING"
    )
    secret = json.loads(metadata['SecretString'])
    
    # Test database connection with new password
    try:
        conn = psycopg2.connect(
            host=secret['host'],
            port=secret['port'],
            database=secret['dbname'],
            user=secret['username'],
            password=secret['password'],  # NEW password
            connect_timeout=5
        )
        
        # Run test query
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        
        if result[0] != 1:
            raise ValueError("Test query failed")
        
        # Verify permissions
        cursor.execute("""
            SELECT has_table_privilege(%s, 'document', 'SELECT')
        """, (secret['username'],))
        
        if not cursor.fetchone()[0]:
            raise ValueError("User lacks required permissions")
        
        cursor.close()
        conn.close()
        
        logger.info("testSecret: Successfully verified new password")
        return True
        
    except Exception as e:
        logger.error(f"testSecret: Verification failed: {str(e)}")
        raise ValueError(f"Failed to verify new password: {str(e)}")
```

#### Rotation Strategies

**Single User Rotation (Simpler):**
- Rotates password for one user
- Brief moment where old connections may fail
- Good for: Development, staging, non-critical workloads

```bash
aws secretsmanager rotate-secret \
  --secret-id elephant/database/app-credentials \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRDSPostgreSQLRotationSingleUser \
  --rotation-rules AutomaticallyAfterDays=30
```

**Alternating User Rotation (Zero-downtime):**
- Creates two users (elephant_app_a, elephant_app_b)
- Rotates between them
- Always one valid user available
- Good for: Production, critical workloads

```bash
aws secretsmanager rotate-secret \
  --secret-id elephant/database/app-credentials \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRDSPostgreSQLRotationMultiUser \
  --rotation-rules AutomaticallyAfterDays=30
```

#### Monitoring Rotation

**CloudWatch Alarms:**

```bash
# Alert on rotation failures
aws cloudwatch put-metric-alarm \
  --alarm-name elephant-db-rotation-failure \
  --alarm-description "Alert when database password rotation fails" \
  --metric-name RotationFailed \
  --namespace AWS/SecretsManager \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:elephant-alerts
```

**Check Rotation Status:**

```bash
# View rotation configuration
aws secretsmanager describe-secret \
  --secret-id elephant/database/app-credentials \
  --query 'RotationEnabled'

# View last rotation date
aws secretsmanager describe-secret \
  --secret-id elephant/database/app-credentials \
  --query 'LastRotatedDate'

# View rotation Lambda logs
aws logs tail /aws/lambda/SecretsManagerRDSPostgreSQLRotationSingleUser --follow
```

**Verify Rotation Success:**

```bash
# Check secret versions and labels
aws secretsmanager list-secret-version-ids \
  --secret-id elephant/database/app-credentials \
  --include-planned-deletion false

# Output shows:
# {
#   "Versions": [
#     {
#       "VersionId": "abc123...",
#       "VersionStages": ["AWSCURRENT"],
#       "CreatedDate": "2024-02-26T10:30:00Z"
#     },
#     {
#       "VersionId": "def456...",
#       "VersionStages": ["AWSPREVIOUS"],
#       "CreatedDate": "2024-01-26T10:30:00Z"
#     }
#   ]
# }

# Test connection with current password
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id elephant/database/app-credentials \
  --query SecretString --output text)

DB_HOST=$(echo $SECRET | jq -r .host)
DB_USER=$(echo $SECRET | jq -r .username)
DB_PASS=$(echo $SECRET | jq -r .password)
DB_NAME=$(echo $SECRET | jq -r .dbname)

PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT current_user, version();"
```

**Monitor Rotation in Real-Time:**

```bash
# Watch Lambda execution logs during rotation
aws logs tail /aws/lambda/elephant-db-rotation --follow --format short

# Example output:
# 2024-02-26T10:30:00 createSecret: Generating new password
# 2024-02-26T10:30:01 createSecret: Created AWSPENDING version
# 2024-02-26T10:30:02 setSecret: Connecting to database
# 2024-02-26T10:30:03 setSecret: Updated password for elephant_app
# 2024-02-26T10:30:04 testSecret: Testing new password
# 2024-02-26T10:30:05 testSecret: Connection successful
# 2024-02-26T10:30:06 testSecret: Permissions verified
# 2024-02-26T10:30:07 finishSecret: Promoting AWSPENDING to AWSCURRENT
# 2024-02-26T10:30:08 finishSecret: Rotation completed successfully
```

**CloudWatch Insights Queries:**

```sql
-- Find failed rotations
fields @timestamp, @message
| filter @message like /ERROR/
| filter @message like /rotation/
| sort @timestamp desc
| limit 20

-- Track rotation duration
fields @timestamp, @duration
| filter @message like /finishSecret: Rotation completed/
| stats avg(@duration), max(@duration), min(@duration) by bin(5m)

-- Monitor testSecret phase
fields @timestamp, @message
| filter @message like /testSecret/
| sort @timestamp desc
```

#### Terraform Configuration

```hcl
# secrets.tf
resource "aws_secretsmanager_secret" "elephant_db_app" {
  name        = "elephant/database/app-credentials"
  description = "Elephant application database credentials"

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_version" "elephant_db_app" {
  secret_id = aws_secretsmanager_secret.elephant_db_app.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_rds_cluster.elephant.endpoint
    port     = 5432
    dbname   = "elephant"
    username = "elephant_app"
    password = random_password.elephant_app.result
  })
}

resource "aws_secretsmanager_secret_rotation" "elephant_db_app" {
  secret_id           = aws_secretsmanager_secret.elephant_db_app.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# Lambda function for rotation
resource "aws_lambda_function" "secrets_rotation" {
  filename      = "rotation-function.zip"
  function_name = "elephant-db-rotation"
  role          = aws_iam_role.secrets_rotation.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.us-east-1.amazonaws.com"
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_rotation.id]
  }
}

# IAM role for rotation Lambda
resource "aws_iam_role" "secrets_rotation" {
  name = "elephant-secrets-rotation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_rotation_basic" {
  role       = aws_iam_role.secrets_rotation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "secrets_rotation" {
  name = "secrets-rotation-policy"
  role = aws_iam_role.secrets_rotation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.elephant_db_app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetRandomPassword"
        ]
        Resource = "*"
      }
    ]
  })
}
```

#### Cost Considerations

**Secrets Manager Pricing (us-east-1):**
- $0.40 per secret per month
- $0.05 per 10,000 API calls
- Rotation Lambda: AWS Lambda pricing applies

**Example monthly cost:**
- 2 secrets (app + reporting): $0.80
- ~100,000 API calls (services fetching secrets): $0.50
- Lambda executions (2 rotations/month): ~$0.01
- **Total: ~$1.31/month**

**Cost optimization:**
- Cache secrets in application (refresh every 1-6 hours)
- Use VPC endpoints to avoid data transfer costs
- Consider AWS Systems Manager Parameter Store for non-sensitive configs (free tier available)

#### Step 4: Verify Connectivity

Test that services can connect with the new password:

```bash
# Check service logs for connection errors
docker compose -f docker-compose.core.yml logs repository | grep -i "password\|auth\|connection"

# Test connection manually
docker exec -it elephant-postgres-1 psql \
  -U elephant_app \
  -d elephant \
  -c "SELECT current_user, current_database();"
```

#### Step 5: Update Backup Scripts

If you have backup scripts using these credentials:

```bash
# Update backup script environment
export PGUSER=elephant_app
export PGPASSWORD=new-strong-password-here

# Or update .pgpass file
echo "postgres:5432:elephant:elephant_app:new-strong-password-here" >> ~/.pgpass
chmod 600 ~/.pgpass
```

### Scenario: Rotating elephant_reporting Password

**Goal:** Change the password for `elephant_reporting` role (used by monitoring/BI tools).

#### Step 1: Generate New Password

```bash
NEW_REPORTING_PASSWORD=$(openssl rand -base64 32)
echo "New reporting password: $NEW_REPORTING_PASSWORD"
```

#### Step 2: Update PostgreSQL Role

```sql
-- Connect as postgres superuser
ALTER ROLE elephant_reporting WITH PASSWORD 'new-reporting-password-here';
```

#### Step 3: Update Monitoring Tools

**Prometheus postgres_exporter:**

```yaml
# prometheus/postgres_exporter.yml
datasource:
  host: postgres
  port: 5432
  database: elephant
  user: elephant_reporting
  password: new-reporting-password-here
  sslmode: require
```

Restart the exporter:
```bash
docker compose -f docker-compose.observability.yml restart postgres-exporter
```

**Grafana datasource:**

```bash
# Update Grafana datasource via API
curl -X PUT http://admin:admin@localhost:3000/api/datasources/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Elephant PostgreSQL",
    "type": "postgres",
    "url": "postgres:5432",
    "database": "elephant",
    "user": "elephant_reporting",
    "secureJsonData": {
      "password": "new-reporting-password-here"
    }
  }'
```

**BI Tools (Metabase, Tableau, etc.):**

Update connection settings in each tool's admin interface.

### Zero-Downtime Rotation Strategy

For production systems that can't tolerate downtime:

#### Step 1: Create Temporary Role

```sql
-- Create a temporary role with same privileges
CREATE ROLE elephant_app_new WITH LOGIN PASSWORD 'new-password';

-- Grant same privileges as elephant_app
GRANT CONNECT ON DATABASE elephant TO elephant_app_new;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO elephant_app_new;
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO elephant_app_new;
```

#### Step 2: Deploy Services with New Credentials

Deploy new service instances using `elephant_app_new`:

```bash
# Blue-green deployment
kubectl apply -f elephant-repository-v2.yaml  # Uses elephant_app_new

# Wait for health checks to pass
kubectl wait --for=condition=ready pod -l app=elephant-repository,version=v2

# Switch traffic to new version
kubectl patch service elephant-repository -p '{"spec":{"selector":{"version":"v2"}}}'
```

#### Step 3: Verify and Clean Up

```sql
-- Check active connections
SELECT usename, count(*) 
FROM pg_stat_activity 
WHERE datname = 'elephant' 
GROUP BY usename;

-- Once elephant_app has no active connections, remove it
DROP ROLE elephant_app;

-- Rename the new role
ALTER ROLE elephant_app_new RENAME TO elephant_app;
```

### Automated Rotation with Scripts

Create a rotation script for regular use:

```bash
#!/bin/bash
# rotate-db-password.sh

set -e

ROLE_NAME=${1:-elephant_app}
NEW_PASSWORD=$(openssl rand -base64 32)

echo "Rotating password for role: $ROLE_NAME"

# Update PostgreSQL
docker exec -it elephant-postgres-1 psql -U postgres -d elephant <<EOF
ALTER ROLE $ROLE_NAME WITH PASSWORD '$NEW_PASSWORD';
EOF

# Update secrets (example for Kubernetes)
kubectl create secret generic elephant-db-credentials \
  --from-literal=username=$ROLE_NAME \
  --from-literal=password=$NEW_PASSWORD \
  --namespace=elephant \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger rolling restart
kubectl rollout restart deployment/elephant-repository -n elephant
kubectl rollout restart deployment/elephant-index -n elephant
kubectl rollout restart deployment/elephant-user -n elephant

echo "Password rotation complete!"
echo "New password stored in Kubernetes secret: elephant-db-credentials"
```

### Best Practices

1. **Rotation Schedule:**
   - Application passwords: Every 90 days
   - Reporting passwords: Every 180 days
   - After any security incident: Immediately

2. **Password Requirements:**
   - Minimum 32 characters
   - Use cryptographically random generation
   - Never reuse old passwords

3. **Secret Management:**
   - Use a secrets manager (AWS Secrets Manager, HashiCorp Vault, etc.)
   - Never commit passwords to git
   - Encrypt secrets at rest

4. **Monitoring:**
   - Alert on failed authentication attempts
   - Log password changes
   - Monitor for unusual connection patterns

5. **Documentation:**
   - Document rotation procedures
   - Keep runbooks updated
   - Test rotation in staging first

### Troubleshooting

**Services can't connect after rotation:**

```bash
# Check PostgreSQL logs
docker logs elephant-postgres-1 | grep -i "authentication\|password"

# Verify role exists and can login
docker exec -it elephant-postgres-1 psql -U postgres -d elephant \
  -c "SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname LIKE 'elephant_%';"

# Test connection manually
PGPASSWORD='new-password' psql -h localhost -p 5432 -U elephant_app -d elephant -c "SELECT 1;"
```

**Old password still works:**

PostgreSQL caches authentication. Force reload:

```sql
SELECT pg_reload_conf();
```

**Connection pool issues:**

Services may have connection pools with old credentials:

```bash
# Restart services to clear connection pools
docker compose -f docker-compose.core.yml restart repository index user
```

## Roles

### elephant_app
**Purpose:** Application user for Elephant services

**Privileges:**
- `SELECT, INSERT, UPDATE, DELETE` on all tables
- `CONNECT` to the database
- Automatically granted privileges on future tables (via DEFAULT PRIVILEGES)

**Used by:**
- elephant-repository (document management)
- elephant-index (search indexing)
- elephant-user (user events and inbox)
- elephant-spell (spellcheck service)

**Why separate from postgres superuser?**
- Security: Limited privileges reduce attack surface
- Auditing: Can track which service made which changes
- Production best practice: Services should never run as superuser

**Current setup:**
- Development: Services connect as `postgres` superuser (for simplicity)
- Production recommendation: Services should use `elephant_app` role

**Configuration example:**
```env
DB_HOST=postgres
DB_PORT=5432
DB_NAME=elephant
DB_USER=elephant_app
DB_PASSWORD=strong-random-password
DB_SSLMODE=require
```

### elephant_reporting
**Purpose:** Read-only user for reporting, analytics, and monitoring

**Privileges:**
- `SELECT` on all tables (read-only)
- `CONNECT` to the database
- `pg_monitor` role for performance monitoring
- Can view pg_stat_statements for query analysis

**Used by:**
- Business intelligence tools (Tableau, Metabase, etc.)
- Analytics dashboards
- Monitoring systems (Prometheus postgres_exporter)
- Data export jobs
- Backup verification scripts

**Why read-only?**
- Safety: Cannot accidentally modify or delete data
- Compliance: Audit logs show reporting never changes data
- Performance: Can run expensive queries without blocking writes

**What pg_monitor provides:**
- Access to pg_stat_statements (query performance)
- Access to pg_stat_activity (current connections)
- Access to pg_stat_database (database statistics)
- Access to pg_stat_replication (replication status)

**Configuration example:**
```env
REPORTING_DB_HOST=postgres
REPORTING_DB_PORT=5432
REPORTING_DB_NAME=elephant
REPORTING_DB_USER=elephant_reporting
REPORTING_DB_PASSWORD=another-strong-password
REPORTING_DB_SSLMODE=require
```

**Monitoring query example:**
```sql
-- Connect as elephant_reporting
-- View current database activity
SELECT pid, usename, application_name, state, query
FROM pg_stat_activity
WHERE datname = 'elephant';

-- View query performance statistics
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

## Extensions

### uuid-ossp
**What it does:** Provides functions for generating UUIDs (Universally Unique Identifiers).

**Why Elephant needs it:**
- Document IDs are UUIDs (e.g., `550e8400-e29b-41d4-a716-446655440000`)
- Version IDs are UUIDs
- Event log entries use UUIDs
- Ensures globally unique identifiers across distributed systems

**Key functions:**
- `uuid_generate_v4()` - Generates random UUIDs
- `uuid_generate_v1()` - Generates time-based UUIDs

**Example usage in Elephant:**
```sql
-- Creating a new document
INSERT INTO document (uuid, type, created, creator_uri)
VALUES (uuid_generate_v4(), 'article', NOW(), 'user:123');
```

### pgcrypto
**What it does:** Provides cryptographic functions for hashing, encryption, and random data generation.

**Why Elephant needs it:**
- Password hashing for user authentication
- API token generation
- Document signing and verification
- Secure random data generation

**Key functions:**
- `gen_random_uuid()` - Alternative UUID generation (faster than uuid-ossp)
- `digest(data, 'sha256')` - Hash data with SHA-256
- `hmac(data, key, 'sha256')` - Generate HMAC signatures
- `crypt(password, gen_salt('bf'))` - Bcrypt password hashing

**Example usage in Elephant:**
```sql
-- Generating a secure API token
SELECT encode(gen_random_bytes(32), 'hex');

-- Hashing a password
UPDATE users SET password_hash = crypt('user_password', gen_salt('bf'));
```

### pg_stat_statements
**What it does:** Tracks execution statistics for all SQL statements executed on the database.

**Why Elephant needs it:**
- Performance monitoring and optimization
- Identifying slow queries
- Understanding query patterns
- Capacity planning

**What it tracks:**
- Query execution time (min, max, average)
- Number of times each query was executed
- Rows returned/affected
- I/O statistics (blocks read/written)
- Cache hit ratios

**Example queries:**
```sql
-- Find slowest queries
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Find most frequently executed queries
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 10;

-- Find queries with poor cache hit ratio
SELECT query, calls,
       shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0) AS cache_hit_ratio
FROM pg_stat_statements
WHERE shared_blks_read > 0
ORDER BY cache_hit_ratio
LIMIT 10;
```

**Monitoring integration:**
- Prometheus can scrape pg_stat_statements via postgres_exporter
- Grafana dashboards can visualize query performance
- Essential for production observability

## Troubleshooting

### Init script fails

Check PostgreSQL logs:
```bash
docker logs elephant-postgres
```

Common issues:
- Syntax errors in SQL
- Trying to create tables that don't exist yet (should be in migrations)
- Permission issues

### Script doesn't run

The init script only runs when the database is first created. If the volume already exists, it won't run again.

Solution:
```bash
# Remove volume and recreate
docker compose -f docker-compose/docker-compose.core.yml down -v
docker compose -f docker-compose/docker-compose.core.yml up -d
```

### Roles already exist

If you see "role already exists" errors, this is usually harmless. The script uses `IF NOT EXISTS` to avoid errors.

## See Also

- [Fresh Start Guide](../../docs/FRESH-START-GUIDE.md) - Complete setup instructions
- [Services Overview](../../docs/SERVICES-OVERVIEW.md) - All services explained
- [Docker Compose README](../../docker-compose/README.md) - Compose file documentation
