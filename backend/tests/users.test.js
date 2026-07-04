import { test, describe, after } from "node:test";
import assert from "node:assert/strict";
import { agent, createUser, cleanup } from "./helpers.js";

describe("users CRUD", () => {
  const createdIds = [];
  after(() => cleanup(...createdIds.map((id) => () => agent.delete(`/api/users/${id}`))));

  test("create user", async () => {
    const user = await createUser();
    createdIds.push(user.id);
    assert.equal(typeof user.id, "number");
    assert.ok(user.username.startsWith("test-user-"));
    assert.equal(user.role, "member");
  });

  test("list users includes created user", async () => {
    const user = await createUser();
    createdIds.push(user.id);
    const res = await agent.get("/api/users");
    assert.equal(res.status, 200);
    assert.ok(res.body.some((u) => u.id === user.id));
  });

  test("get single user", async () => {
    const user = await createUser();
    createdIds.push(user.id);
    const res = await agent.get(`/api/users/${user.id}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.id, user.id);
  });

  test("update user", async () => {
    const user = await createUser();
    createdIds.push(user.id);
    const newUsername = `${user.username}-renamed`;
    const res = await agent.put(`/api/users/${user.id}`).send({ username: newUsername });
    assert.equal(res.status, 200);
    assert.equal(res.body.username, newUsername);
  });

  test("delete user", async () => {
    const user = await createUser();
    const res = await agent.delete(`/api/users/${user.id}`);
    assert.equal(res.status, 204);
    const getRes = await agent.get(`/api/users/${user.id}`);
    assert.equal(getRes.status, 404);
  });
});
