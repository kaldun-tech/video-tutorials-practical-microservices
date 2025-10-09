# Deployment Notes - DigitalOcean App Platform

## Overview
This document captures lessons learned while deploying the video-tutorials-practical-microservices application to DigitalOcean App Platform with a managed PostgreSQL database.

## Architecture Diagram

```mermaid
graph TB
    subgraph "DigitalOcean App Platform"
        LB[Load Balancer<br/>SSL Termination<br/>*.ondigitalocean.app]

        subgraph "App Containers"
            App1[App Instance 1<br/>Node.js 20<br/>Express Server<br/>Port 8080]
            App2[App Instance 2<br/>Node.js 20<br/>Express Server<br/>Port 8080]
        end

        LB --> App1
        LB --> App2
    end

    subgraph "Managed PostgreSQL Databases"
        DB_APP[(Application DB<br/>practical_microservices<br/>Knex Migrations<br/>Tables: users, videos, pages)]
        DB_MSG[(Message Store DB<br/>message_store<br/>Message-DB Schema<br/>Event Sourcing)]
    end

    subgraph "Application Components"
        Agg[Aggregators<br/>home-page<br/>user-credentials<br/>video-operations]
        Comp[Components<br/>identity<br/>send-email<br/>video-publishing]
    end

    Internet[Internet/Users] -->|HTTPS| LB

    App1 --> Agg
    App2 --> Agg
    Agg --> Comp

    App1 -->|Knex ORM| DB_APP
    App2 -->|Knex ORM| DB_APP

    App1 -->|Message-DB<br/>write_message<br/>get_stream_messages| DB_MSG
    App2 -->|Message-DB<br/>write_message<br/>get_stream_messages| DB_MSG

    Comp -.->|Event Sourcing<br/>Domain Events| DB_MSG
    Agg -.->|Read Projections<br/>CQRS| DB_APP

    style LB fill:#0080ff,color:#fff
    style App1 fill:#0080ff,color:#fff
    style App2 fill:#0080ff,color:#fff
    style DB_APP fill:#326CE5,color:#fff
    style DB_MSG fill:#326CE5,color:#fff
    style Agg fill:#90EE90
    style Comp fill:#FFB366
```

### Architecture Highlights

**Event Sourcing Pattern:**
- Components write domain events to Message Store DB
- Events are immutable and form complete audit trail
- Aggregators read events and build projections in Application DB

**CQRS Implementation:**
- **Write side:** Commands → Components → Events → Message Store
- **Read side:** Aggregators → Projections → Application DB
- Separate read/write models for optimal performance

**High Availability:**
- Load balancer distributes traffic across multiple app instances
- Auto-scaling based on CPU/memory usage
- Database connection pooling for efficient resource usage

## Database Architecture

The application requires **two separate databases**:

### 1. Application Database (`practical_microservices`)
- Stores application data via Knex ORM
- Tables created automatically via Knex migrations on startup
- Tables include:
  - `pages` - page data storage
  - `user_credentials` - user authentication
  - `admin_users` - admin user management
  - `videos` - video metadata
  - `creators_portal_videos` - creator video information
  - `video_operations` - video operation tracking
  - `admin_streams` - admin stream tracking
  - `admin_subscriber_positions` - subscriber position tracking

### 2. Message Store Database (`message_store`)
- Event sourcing database using @eventide/message-db
- Requires manual installation of message-db schema
- Contains:
  - `message_store` schema
  - `messages` table
  - Event sourcing functions (write_message, get_stream_messages, etc.)
  - Views and indexes for event querying

## Environment Configuration

### Required Environment Variables
```bash
# Base connection (no trailing slash, no database name)
DIGITALOCEAN_URL="postgresql://doadmin:password@host:25060"

# Application databases
DATABASE_URL="${DIGITALOCEAN_URL}/practical_microservices?sslmode=require"
MESSAGE_STORE_CONNECTION_STRING="${DIGITALOCEAN_URL}/message_store?sslmode=require"

# Application settings
NODE_ENV="production"
PORT="8080"
APP_NAME="video-tutorials-practical-microservices"
COOKIE_SECRET="your-secret-here"
EMAIL_DIRECTORY="/tmp/email"
SYSTEM_SENDER_EMAIL_ADDRESS="noreply@example.com"
```

### Local vs Production
- **Local**: Uses `.env` file, fails if missing
- **Production**: Uses platform environment variables, `.env` file not deployed
- Modified `src/env.js` to only require `.env` in non-production environments

## SSL Certificate Handling

DigitalOcean managed databases use SSL certificates that Node.js treats as self-signed.

### Solution
Both database clients need SSL configuration:

**Knex Client** (`src/knex-client.js`):
```javascript
const client = knex({
  client: 'pg',
  connection: connectionString,
  ssl: { rejectUnauthorized: false }
})
```

**Postgres Client** (`src/postgres-client.js`):
```javascript
const client = new pg.Client({
  connectionString: url.toString(),
  ssl: { rejectUnauthorized: false },
  Promise: Bluebird
})
```

## Message-DB Installation

### Issue
The standard message-db installation script expects:
- Standard PostgreSQL setup with `postgres` admin database
- Ability to create roles
- Local socket connections

DigitalOcean managed databases:
- Use `defaultdb` instead of `postgres`
- Don't allow role creation (uses `doadmin` superuser)
- Require remote TCP connections with SSL

### Solution
Created custom installation script at `scripts/install-message-store.js` that:
1. Parses connection string to extract host, port, user, password
2. Sets proper `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` environment variables
3. Installs SQL files directly in correct order
4. Skips role creation (not needed with managed databases)

### Installation Steps
```bash
# 1. Create databases in DigitalOcean UI
#    - practical_microservices
#    - message_store

# 2. Set environment variables (locally or on server)

# 3. Clean install message-db (if schema exists in inconsistent state)
psql "${MESSAGE_STORE_CONNECTION_STRING}" -c "DROP SCHEMA IF EXISTS message_store CASCADE;"

# 4. Run installation
npm run install-message-store

# 5. Verify installation
psql "${MESSAGE_STORE_CONNECTION_STRING}" -c "\dt message_store.*"
psql "${MESSAGE_STORE_CONNECTION_STRING}" -c "\df message_store.*"
```

## Build Process

### Package Lock Synchronization
The deployment failed initially because `package-lock.json` was out of sync with `package.json`.

**Error**:
```
npm ci can only install packages when your package.json and package-lock.json are in sync
Missing: @eventide/message-db@1.3.1 from lock file
```

**Solution**: Run `npm install` locally to update `package-lock.json`, then commit.

### NPM CI vs NPM Install
- DigitalOcean uses `npm ci` for reproducible builds
- `npm ci` requires exact sync between package.json and package-lock.json
- Always commit package-lock.json changes

## Common Deployment Issues

### 1. "self-signed certificate in certificate chain"
- **Cause**: Node.js pg client rejecting DigitalOcean's SSL certificate
- **Fix**: Add `ssl: { rejectUnauthorized: false }` to database client config

### 2. "function get_last_stream_message(unknown) does not exist"
- **Cause**: message-db schema not installed in message_store database
- **Fix**: Run `npm run install-message-store` with proper connection string

### 3. "multiple primary keys for table 'messages' are not allowed"
- **Cause**: Partial/corrupted message_store schema from previous installation attempt
- **Fix**: Drop and recreate schema: `DROP SCHEMA IF EXISTS message_store CASCADE;`

### 4. "database 'postgres' does not exist"
- **Cause**: Script trying to use standard postgres admin database
- **Fix**: Use custom install script that works with DigitalOcean's defaultdb

### 5. Missing .env file in production
- **Cause**: .env files are not deployed to production
- **Fix**: Configure environment variables in platform UI, modify code to not require .env in production

## Database Setup Checklist

- [x] Create `practical_microservices` database in DigitalOcean
- [x] Create `message_store` database in DigitalOcean
- [x] Add computer IP to database firewall trusted sources
- [x] Set `DATABASE_URL` environment variable (local and production)
- [x] Set `MESSAGE_STORE_CONNECTION_STRING` environment variable (local and production)
- [x] Run `npm run install-message-store` to install message-db schema
- [x] Verify message_store functions exist: `\df message_store.*`
- [x] Commit and push package-lock.json if updated
- [x] Deploy to DigitalOcean App Platform
- [x] Monitor deployment logs for SSL and database connection errors

## Debugging Commands

```bash
# Connect to production database
psql "${MESSAGE_STORE_CONNECTION_STRING}"

# List schemas
\dn

# List tables in message_store schema
\dt message_store.*

# List functions in message_store schema
\df message_store.*

# Check app database tables
psql "${DATABASE_URL}" -c "\dt"

# Test message-db function
psql "${MESSAGE_STORE_CONNECTION_STRING}" -c "SELECT message_store.message_store_version();"

# View deployment logs
# (Use DigitalOcean App Platform console)
```

## References

- [Message-DB Documentation](https://github.com/message-db/message-db)
- [@eventide/message-db NPM Package](https://www.npmjs.com/package/@eventide/message-db)
- [DigitalOcean Managed PostgreSQL Docs](https://docs.digitalocean.com/products/databases/postgresql/)
- [Knex.js Migrations](https://knexjs.org/guide/migrations.html)

## Recent Updates

### 2025-10-09 - Successful Production Deployment ✅
- **Application URL:** https://kt-video-tutorials-gn4cw.ondigitalocean.app/
- **Status:** Fully operational
- Installed message-db schema on production database
- Configured encrypted environment variables in DigitalOcean App Platform
- Verified all components working:
  - ✅ Health check endpoint (`/health`)
  - ✅ Home page with video statistics
  - ✅ Admin portal with Users, Messages, Streams, Categories
  - ✅ User registration and authentication
  - ✅ Creator's Portal
  - ✅ Event sourcing and message store functions

### 2025-10-08 - SSL Connection Improvements
Updated both `src/knex-client.js` and `src/postgres-client.js` to automatically detect local vs remote connections:
- **Local connections** (localhost/127.0.0.1): SSL disabled
- **Remote connections** (DigitalOcean, etc.): SSL enabled with `rejectUnauthorized: false`
- Also removes `?sslmode=require&ssl=true` query parameters that can interfere with connection

### Categories Feature Added
Added new admin portal feature at `/admin/categories`:
- Lists all message categories with message counts
- Click through to view messages by category
- Follows existing patterns for streams and messages

### Creators Portal Route Added
Mounted creators portal at `/creators-portal` - was implemented but not connected to routes

## Deployment Completed ✅

**Production Environment:**
- **URL:** https://kt-video-tutorials-gn4cw.ondigitalocean.app/
- **Platform:** DigitalOcean App Platform
- **Region:** Auto-selected (likely NYC3)
- **Instances:** 2 (high availability)
- **Databases:** 2 managed PostgreSQL instances
  - Application DB: `practical_microservices` (Knex migrations)
  - Message Store DB: `message_store` (Message-DB schema)

**Completed Tasks:**
- [x] Resolve SSL certificate errors
- [x] Configure environment variables as encrypted secrets
- [x] Install message-db schema on production database
- [x] Verify all aggregators and components start successfully
- [x] Test full application functionality in production
- [x] Add health check endpoint for deployment monitoring

**Future Enhancements (Optional):**
- [ ] Consider using DigitalOcean's CA certificate instead of disabling certificate verification
- [ ] Document email handling in production (currently uses local pickup transport to `/tmp/email`)
- [ ] Set up custom domain and DNS
- [ ] Configure monitoring alerts for high CPU/memory usage
- [ ] Implement log aggregation for better debugging
