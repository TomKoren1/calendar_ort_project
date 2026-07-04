import express from "express";
import cors from "cors";
import usersRouter from "./routes/users.js";
import eventsRouter from "./routes/events.js";
import calendarsRouter from "./routes/calendars.js";
import tagsRouter from "./routes/tags.js";

const app = express();

app.use(cors());
app.use(express.json());

app.use("/api/users", usersRouter);
app.use("/api/events", eventsRouter);
app.use("/api/calendars", calendarsRouter);
app.use("/api/tags", tagsRouter);

app.get("/api/health", (req, res) => res.json({ ok: true }));

app.use((err, req, res, next) => {
  if (err.code === "23503") {
    return res.status(409).json({ error: "invalid reference to a related record" });
  }
  console.error(err);
  res.status(500).json({ error: "internal server error" });
});

export default app;
