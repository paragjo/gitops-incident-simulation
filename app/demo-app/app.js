const express = require("express");
const client = require("prom-client");

const app = express();
const PORT = process.env.PORT || 3000;

// ==============================
// PROMETHEUS SETUP (SAFE)
// ==============================
const register = new client.Registry();

client.collectDefaultMetrics({
  register,
});

// Custom metric
const httpRequestCounter = new client.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
});

register.registerMetric(httpRequestCounter);

// ==============================
// FAILURE MODES
// ==============================
const failureMode = process.env.FAILURE_MODE || "none";

function log(level, message, extra = {}) {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    failureMode,
    ...extra
  }));
}

// Crash loop
if (failureMode === "crash-loop") {
  log("error", "Simulating crash loop on startup");
  process.exit(1);
}

// Memory leak
let memoryLeak = [];
setInterval(() => {
  if (failureMode === "memory-leak") {
    const chunk = new Array(1000000).fill("leak");
    memoryLeak.push(chunk);

    log("warn", "Memory leak growing", {
      heapChunks: memoryLeak.length
    });
  }
}, 1000);

// ==============================
// MIDDLEWARE (SAFE)
// ==============================
app.use((req, res, next) => {
  try {
    httpRequestCounter.inc();
  } catch (err) {
    console.error("Metric error:", err);
  }
  next();
});

// ==============================
// ROUTES
// ==============================

// Root
app.get("/", (req, res) => {
  res.json({
    status: "ok",
    failureMode
  });
});

// Health
app.get("/health", (req, res) => {
  if (failureMode === "health-fail") {
    log("error", "Health check failing intentionally");
    return res.status(500).send("NOT OK");
  }
  res.status(200).send("OK");
});

// API
app.get("/api", async (req, res) => {
  log("info", "Incoming request", { path: "/api" });

  if (failureMode === "latency") {
    log("warn", "Injecting latency");
    await new Promise(r => setTimeout(r, 3000));
  }

  if (failureMode === "cpu-spike") {
    log("warn", "Simulating CPU spike");
    const end = Date.now() + 5000;
    while (Date.now() < end) {
      Math.random();
    }
  }

  if (failureMode === "crash") {
    log("error", "Crashing on API request");
    process.exit(1);
  }

  res.json({
    message: "Hello from demo app",
    failureMode
  });
});

// Metrics (SAFE)
app.get("/metrics", async (req, res) => {
  try {
    res.set("Content-Type", register.contentType);
    const metrics = await register.metrics();
    res.end(metrics);
  } catch (err) {
    console.error("Metrics error:", err);
    res.status(500).send("Metrics error");
  }
});

// ==============================
// START SERVER
// ==============================
app.listen(PORT, () => {
  log("info", `App running on port ${PORT}`);
});
