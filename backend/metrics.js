import client from "prom-client";

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

const httpRequestDurationSeconds = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

// req.route is only populated once Express has matched a route, so this has
// to read it in the "finish" handler (fires after the response is sent, well
// after routing), not up front. Falls back to "unmatched" for 404s - using
// the raw path instead would create a distinct label value per unique URL
// (e.g. every /api/events/:id), which blows up Prometheus's cardinality.
export function metricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();

  res.on("finish", () => {
    const route = req.route?.path ? `${req.baseUrl}${req.route.path}` : "unmatched";
    const labels = { method: req.method, route, status_code: res.statusCode };
    httpRequestsTotal.inc(labels);
    httpRequestDurationSeconds.observe(labels, Number(process.hrtime.bigint() - start) / 1e9);
  });

  next();
}

export async function metricsHandler(req, res) {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
}
