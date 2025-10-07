# video-tutorials-practical-microservices
Video tutorials app from Practical Microservices by Ethan Garafolo

Visit https://pragprog.com/titles/egmicro for more book information.

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
    B -->|AWS Portfolio| C[AWS ECS Fargate]
    B -->|Quick AWS Start| D[AWS Elastic Beanstalk]
    B -->|Simplicity & Cost| E[DigitalOcean]

    style C fill:#ff9900
    style D fill:#ff9900
    style E fill:#0080ff
```

**See [Platform Comparison Guide](./docs/deployment/comparison.md)** for detailed cost analysis, architecture diagrams, and trade-offs.
