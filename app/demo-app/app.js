const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

// Read failure mode
const failureMode = process.env.FAILURE_MODE || "none";

// Structured logger
function log(level, message, extra = {}) {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    failureMode,
    ...extra
  }));
}

// ==============================
// 🔥 STARTUP FAILURE (CrashLoop)
// ==============================
if (failureMode === "crash-loop") {
  log("error", "Simulating crash loop on startup");
  process.exit(1);
}

// ==============================
// 🔥 MEMORY LEAK SIMULATION
// ==============================
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
// ROUTES
// ==============================

// Root
app.get("/", (req, res) => {
  res.json({
    status: "ok",
    failureMode
  });
});

// Health (used by probes)
app.get("/health", (req, res) => {
  if (failureMode === "health-fail") {
    log("error", "Health check failing intentionally");
    return res.status(500).send("NOT OK");
  }

  res.status(200).send("OK");
});

// API endpoint (simulate runtime issues)
app.get("/api", async (req, res) => {
  log("info", "Incoming request", {
    path: "/api"
  });

  // 🔥 LATENCY
  if (failureMode === "latency") {
    log("warn", "Injecting latency");
    await new Promise(r => setTimeout(r, 3000));
  }

  // 🔥 CPU SPIKE
  if (failureMode === "cpu-spike") {
    log("warn", "Simulating CPU spike");
    const end = Date.now() + 5000;
    while (Date.now() < end) {
      Math.random();
    }
  }

  // 🔥 RUNTIME CRASH
  if (failureMode === "crash") {
    log("error", "Crashing on API request");
    process.exit(1);
  }

  res.json({
    message: "Hello from demo app",
    failureMode
  });
});

// ==============================
// START SERVER
// ==============================
app.listen(PORT, () => {
  log("info", `App running on port ${PORT}`);
});
