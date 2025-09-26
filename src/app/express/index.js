const express = require("express");
const {join} = require("path");

const mountMiddleware = require("./middleware");
const mountRoutes = require("./routes");

function createExpressApp( { config, env }) {
    const app = express();

    // Configure PUG
    app.set("views", join(__dirname, ".."));
    app.set("view engine", "pug");
    
    mountMiddleware(app);
    mountRoutes(app);

    return app;
}

module.exports = createExpressApp;
