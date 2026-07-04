import { test, describe, after } from "node:test";
import assert from "node:assert/strict";
import { agent, createTag, cleanup } from "./helpers.js";

describe("tags CRUD", () => {
  const createdIds = [];
  after(() => cleanup(...createdIds.map((id) => () => agent.delete(`/api/tags/${id}`))));

  test("create tag", async () => {
    const tag = await createTag();
    createdIds.push(tag.id);
    assert.equal(typeof tag.id, "number");
    assert.ok(tag.name.startsWith("test-tag-"));
    assert.equal(tag.color, "#ffffff");
  });

  test("list tags includes created tag", async () => {
    const tag = await createTag();
    createdIds.push(tag.id);
    const res = await agent.get("/api/tags");
    assert.equal(res.status, 200);
    assert.ok(res.body.some((t) => t.id === tag.id));
  });

  test("get single tag", async () => {
    const tag = await createTag();
    createdIds.push(tag.id);
    const res = await agent.get(`/api/tags/${tag.id}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.id, tag.id);
  });

  test("update tag", async () => {
    const tag = await createTag();
    createdIds.push(tag.id);
    const newName = `${tag.name}-renamed`;
    const res = await agent.put(`/api/tags/${tag.id}`).send({ name: newName });
    assert.equal(res.status, 200);
    assert.equal(res.body.name, newName);
  });

  test("delete tag", async () => {
    const tag = await createTag();
    const res = await agent.delete(`/api/tags/${tag.id}`);
    assert.equal(res.status, 204);
    const getRes = await agent.get(`/api/tags/${tag.id}`);
    assert.equal(getRes.status, 404);
  });
});
