import { test, describe, after } from "node:test";
import assert from "node:assert/strict";
import { agent, createCalendar, cleanup } from "./helpers.js";

describe("calendars CRUD", () => {
  const createdIds = [];
  after(() =>
    cleanup(...createdIds.map((id) => () => agent.delete(`/api/calendars/${id}`)))
  );

  test("create calendar", async () => {
    const calendar = await createCalendar();
    createdIds.push(calendar.id);
    assert.equal(typeof calendar.id, "number");
    assert.ok(calendar.name.startsWith("test-calendar-"));
  });

  test("list calendars includes created calendar", async () => {
    const calendar = await createCalendar();
    createdIds.push(calendar.id);
    const res = await agent.get("/api/calendars");
    assert.equal(res.status, 200);
    assert.ok(res.body.some((c) => c.id === calendar.id));
  });

  test("get single calendar", async () => {
    const calendar = await createCalendar();
    createdIds.push(calendar.id);
    const res = await agent.get(`/api/calendars/${calendar.id}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.id, calendar.id);
  });

  test("update calendar", async () => {
    const calendar = await createCalendar();
    createdIds.push(calendar.id);
    const newName = `${calendar.name}-renamed`;
    const res = await agent.put(`/api/calendars/${calendar.id}`).send({ name: newName });
    assert.equal(res.status, 200);
    assert.equal(res.body.name, newName);
  });

  test("delete calendar", async () => {
    const calendar = await createCalendar();
    const res = await agent.delete(`/api/calendars/${calendar.id}`);
    assert.equal(res.status, 204);
    const getRes = await agent.get(`/api/calendars/${calendar.id}`);
    assert.equal(getRes.status, 404);
  });
});
