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

3. Set up the database:
   - Create a PostgreSQL database named `video_tutorials`
   - Run migrations:
     ```bash
     npx knex migrate:latest
     ```

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
  - `bin/` - Executable scripts
  - `config.js` - Application configuration
  - `env.js` - Environment variable handling
  - `knex-client.js` - Database client setup
- `migrations/` - Database migration files
- `public/` - Static assets (CSS, JS, images)
