import { randomUUID } from "node:crypto";
import request from "supertest";
import app from "../app.js";

export const agent = request(app);

export function uniqueName(prefix) {
  return `${prefix}-${randomUUID()}`;
}

async function post(path, body) {
  const res = await agent.post(path).send(body);
  if (res.status !== 201) {
    throw new Error(`POST ${path} failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return res.body;
}

export function createUser(overrides = {}) {
  return post("/api/users", { username: uniqueName("test-user"), ...overrides });
}

export function createCalendar(overrides = {}) {
  return post("/api/calendars", { name: uniqueName("test-calendar"), ...overrides });
}

export function createTag(overrides = {}) {
  return post("/api/tags", {
    name: uniqueName("test-tag"),
    color: "#ffffff",
    ...overrides,
  });
}

export function createEvent(calendarId, tagId, overrides = {}) {
  return post("/api/events", {
    name: uniqueName("test-event"),
    start_datetime: "2026-08-01T10:00:00",
    end_datetime: "2026-08-01T11:00:00",
    calendar_id: calendarId,
    tag_id: tagId,
    ...overrides,
  });
}

// Best-effort cleanup: awaits each delete, swallows/logs errors so one
// failed delete doesn't hide the rest.
export async function cleanup(...deleteFns) {
  for (const del of deleteFns) {
    try {
      await del();
    } catch (err) {
      console.error("cleanup error (ignored):", err.message);
    }
  }
}
