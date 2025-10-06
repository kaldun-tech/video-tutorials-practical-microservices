const express = require("express");
const {join} = require("path");

const mountMiddleware = require("./middleware");
const mountRoutes = require("./routes");

function createExpressApp( { config, env }) {
    const app = express();

    // Configure PUG
    app.set("views", join(__dirname, ".."));
    app.set("view engine", "pug");
    
    mountMiddleware(app, env);
    mountRoutes(app, config);

    return app;
}

// Health check endpoint for DigitalOcean
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  })
})

// Root endpoint
app.get('/', (req, res) => {
  res.redirect('/home')
})

module.exports = createExpressApp;
