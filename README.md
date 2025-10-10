# video-tutorials-practical-microservices
Video tutorials app from Practical Microservices by Ethan Garafolo.

This presents building a video tutorials app from scratch using microservices and event sourcing.

Visit https://pragprog.com/titles/egmicro for more book information.

## What I learned
- Microservices help organizations scale as they grow, but they also add complexity. 
- Modular monoliths are preferable for getting new software projects started.
- Event sourcing in distributed systems provides an immutable audit trail of all state changes.
- Idempotent message processing is important for building distributed systems. This prevents duplicate processing of messages.
- CQRS is a pattern that separates read and write models. This allows for optimized access patterns.
- The event store is a specialized database that stores events in a way that allows for temporal queries and replay of events.
- Aggregates are a domain-driven design pattern that represent clusters of related objects treated as a single unit.
- This system has eventual consistency, similar to NoSQL databases like MongoDB. Services may not immediately reflect the latest state of the system.
- Defining clear boundaries between services is critical to defining the scope of each service.

## Fintech-Relevant Patterns

This project demonstrates several architectural patterns that are critical for **financial services applications**:

### 🔒 Event Sourcing with Message-DB
- **Complete audit trail** - Every state change is stored as an immutable event
- **Temporal queries** - Reconstruct system state at any point in time
- **Regulatory compliance** - Full transaction history for auditing (SOX, PCI-DSS)
- **Example use case:** Financial transaction ledgers, account balance history

### ⚡ Idempotent Message Processing
- **At-least-once delivery** - Safe message reprocessing without duplicate effects
- **Distributed transaction safety** - Prevents double-charging, duplicate payments
- **Example use case:** Payment processing, fund transfers, settlement operations

### 📊 CQRS (Command Query Responsibility Segregation)
- **Separate read/write models** - Optimized for different access patterns
- **Event-driven projections** - Real-time materialized views from event streams
- **Example use case:** Account balance views, transaction history, compliance reports

### 🔍 Audit Trails & Compliance
- **Immutable event log** - Tamper-proof transaction history
- **Message versioning** - Track schema evolution over time
- **Causation tracking** - Full correlation between related events
- **Example use case:** Fraud detection, dispute resolution, regulatory audits

### 🏗️ Microservices with Domain Events
- **Eventual consistency** - Loosely coupled services communicate via events
- **Autonomous components** - Independent deployment and scaling
- **Example use case:** Payment processing, risk assessment, notification systems

**Why this matters for fintech:** Financial systems require strong guarantees around data consistency, auditability, and reliability. Event sourcing provides an immutable audit log, idempotence prevents duplicate transactions, and CQRS enables real-time reporting without impacting transaction processing.

## Tech Stack
- Node.js
- Express.js
- PostgreSQL run locally in a Docker container
- Knex.js
- Bluebird
- Blue-tape
- Pug
- DigitalOcean App Platform

## Prerequisites
- Node.js 20.11.0
- PostgreSQL 16
- Knex CLI 2.5.0
- Bluebird 3.5.6
- Blue-tape 1.0.3
- Pug 3.0.2

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Set up environment variables:
   Create a `.env` file in the root directory with the following variables:
   ```
   APP_NAME=video-tutorials-practical-microservices
   DATABASE_URL=postgresql://username:password@localhost:5432/video_tutorials
   NODE_ENV=development
   PORT=3000
   ```

3. Set up the databases:

   **Application Database:**
   - Create a PostgreSQL database named `video_tutorials`
   - Run migrations:
     ```bash
     npx knex migrate:latest
     ```

   **Message Store Database:**
   - Create a PostgreSQL database named `message_store`
   - Install Message DB schema:
     ```bash
     MESSAGE_STORE_CONNECTION_STRING=postgresql://username:password@localhost:5432/message_store npm run install-message-store
     ```

   **Note:** The application requires TWO databases:
   - `DATABASE_URL` - Application data (users, videos, pages)
   - `MESSAGE_STORE_CONNECTION_STRING` - Event sourcing messages

## Running the Application

### Development Mode
Start the application with auto-restart on file changes:
```bash
npm run dev
```

### Production Mode
Start the application:
```bash
npm start
```

### Alternative Development Server
Start using the custom development server:
```bash
npm run start-dev-server
```

The application will be available at `http://localhost:3000` (or the port specified in your `.env` file).

## Testing

Run the test suite using blue-tape:
```bash
# Currently no test script is configured, run tests directly:
node src/app/home/home.test.js
```

Note: The project uses blue-tape for testing. The main test file is located at `src/app/home/home.test.js`.

## Architecture

This application demonstrates event-sourced microservices using CQRS pattern:

```mermaid
graph TB
    subgraph "User Interface Layer"
        UI[Express.js App<br/>Routes & Templates]
    end

    subgraph "Application Layer"
        Home[Home Page]
        Record[Record Viewings]
        Register[Register Users]
        Auth[Authentication]
    end

    subgraph "CQRS Pattern"
        direction LR

        subgraph "Write Side - Commands"
            Components[Components<br/>Identity<br/>Send Email<br/>Video Publishing]
        end

        subgraph "Event Store"
            MessageStore[(Message Store<br/>PostgreSQL<br/>Event Sourcing)]
        end

        subgraph "Read Side - Queries"
            Aggregators[Aggregators<br/>Home Page<br/>User Credentials<br/>Video Operations]
        end
    end

    subgraph "Data Layer"
        AppDB[(Application DB<br/>PostgreSQL<br/>Projections)]
    end

    UI --> Home
    UI --> Record
    UI --> Register
    UI --> Auth

    Home --> Aggregators
    Record --> Components
    Register --> Components
    Auth --> Aggregators

    Components -->|write_message<br/>Domain Events| MessageStore
    MessageStore -->|Event Stream| Aggregators
    Aggregators -->|Materialize<br/>Projections| AppDB

    Components -.->|Subscribe to<br/>Events| MessageStore

    style UI fill:#E8F5E9
    style Components fill:#FFE0B2
    style MessageStore fill:#E1F5FE
    style Aggregators fill:#F3E5F5
    style AppDB fill:#E1F5FE
```

### Key Patterns

**Event Sourcing**: All state changes stored as immutable events in Message Store
**CQRS**: Separate write model (Components → Events) from read model (Aggregators → Projections)
**Eventual Consistency**: Aggregators asynchronously build projections from event streams
**Idempotent Processing**: Safe message reprocessing with at-least-once delivery

## Project Structure

- `src/` - Source code
  - `app/` - Application modules
    - `express/` - Express.js server setup
    - `home/` - Home page functionality and tests
    - `record-viewings/` - Video viewing recording functionality
    - `register-users/` - User registration functionality
    - `authenticate/` - Authentication functionality
  - `aggregators/` - Event aggregators
    - `home-page/` - Home page data aggregation
    - `user-credentials/` - User credentials aggregation
    - `video-operations/` - Video operations aggregation
  - `components/` - Microservices components
    - `identity/` - Identity management
    - `send-email/` - Email sending component
    - `video-publishing/` - Video publishing component
  - `message-store/` - Message store implementation
  - `bin/` - Executable scripts
  - `config.js` - Application configuration
  - `env.js` - Environment variable handling
  - `knex-client.js` - Database client setup
  - `postgres-client.js` - PostgreSQL client for message store
- `migrations/` - Database migration files
- `public/` - Static assets (CSS, JS, images)
- `docs/` - Documentation
  - `deployment/` - **Deployment guides for AWS, DigitalOcean**

## Deployment

This application can be deployed to various cloud platforms. Comprehensive deployment guides are available:

### 📚 [Deployment Documentation](./docs/deployment/README.md)

Choose your deployment platform based on your goals:

| Platform | Setup Time | Monthly Cost | Best For |
|----------|------------|--------------|----------|
| **[AWS Elastic Beanstalk](./docs/deployment/elastic-beanstalk.md)** | 4-6 hours | ~$65-175 | Quick AWS deployment, Heroku alternative |
| **[AWS ECS Fargate](./docs/deployment/ecs-fargate.md)** | 20-30 hours | ~$100-225 | **AWS portfolio building**, production microservices |
| **[DigitalOcean](./docs/deployment/digitalocean.md)** | 2-4 hours | ~$40-130 | Simplicity, cost-effectiveness, MVPs |

### Quick Decision Guide

```mermaid
graph TD
    A[Choose Deployment] --> B{Primary Goal?}
    B -->|AWS Portfolio Building| C[AWS ECS Fargate]
    B -->|Quick AWS Start| D[AWS Elastic Beanstalk]
    B -->|Simplicity & Cost| E[DigitalOcean]

    style C fill:#ff9900
    style D fill:#ff9900
    style E fill:#0080ff
```

**See [Platform Comparison Guide](./docs/deployment/comparison.md)** for detailed cost analysis, architecture diagrams, and trade-offs.
