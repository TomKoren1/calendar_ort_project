import { test, describe, after } from "node:test";
import assert from "node:assert/strict";
import {
  agent,
  createCalendar,
  createTag,
  createEvent,
  cleanup,
} from "./helpers.js";

describe("events CRUD + FK constraint behavior", () => {
  const cleanupFns = [];
  after(() => cleanup(...cleanupFns));

  test("full CRUD lifecycle", async () => {
    const calendar = await createCalendar();
    const tag = await createTag();
    const event = await createEvent(calendar.id, tag.id);

    cleanupFns.push(
      () => agent.delete(`/api/events/${event.id}`),
      () => agent.delete(`/api/tags/${tag.id}`),
      () => agent.delete(`/api/calendars/${calendar.id}`)
    );

    assert.equal(event.calendar_id, calendar.id);
    assert.equal(event.tag_id, tag.id);

    const getRes = await agent.get(`/api/events/${event.id}`);
    assert.equal(getRes.status, 200);

    const updateRes = await agent
      .put(`/api/events/${event.id}`)
      .send({ name: `${event.name}-updated` });
    assert.equal(updateRes.status, 200);
    assert.equal(updateRes.body.name, `${event.name}-updated`);
  });

  test("deleting a tag referenced by an event returns 409; deleting the event first allows it", async () => {
    const calendar = await createCalendar();
    const tag = await createTag();
    const event = await createEvent(calendar.id, tag.id);

    // event still references tag -> deleting the tag must be rejected
    const blockedDelete = await agent.delete(`/api/tags/${tag.id}`);
    assert.equal(blockedDelete.status, 409);

    // remove the referencing event first
    const eventDelete = await agent.delete(`/api/events/${event.id}`);
    assert.equal(eventDelete.status, 204);

    // now the tag delete succeeds
    const tagDelete = await agent.delete(`/api/tags/${tag.id}`);
    assert.equal(tagDelete.status, 204);

    await cleanup(() => agent.delete(`/api/calendars/${calendar.id}`));
  });
});
