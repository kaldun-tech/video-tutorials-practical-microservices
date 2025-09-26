const express = require("express");
const {join} = require("path");

const attachLocals = require('./attach-locals')
const lastResortErrorHandler = require('./last-resort-error-handler')
const primeRequestContext = require('./prime-request-context')

function mountMiddleware(app, env) {
    app.use(primeRequestContext)
    app.use(attachLocals)
    app.use(lastResortErrorHandler)
    app.use(express.static(join(__dirname, "..", "public"), {maxAge: 86400000}))
}

module.exports = mountMiddleware