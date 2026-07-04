import db from "../db.js";

export async function list(req, res) {
  const { rows } = await db.query('SELECT * FROM "user" ORDER BY id DESC');
  res.json(rows);
}

export async function getOne(req, res) {
  const { rows } = await db.query('SELECT * FROM "user" WHERE id = $1', [
    req.params.id,
  ]);
  if (!rows[0]) return res.status(404).json({ error: "user not found" });
  res.json(rows[0]);
}

export async function create(req, res) {
  const { username, role } = req.body;
  if (!username) {
    return res.status(400).json({ error: "username is required" });
  }
  const { rows } = await db.query(
    'INSERT INTO "user" (username, role) VALUES ($1, $2) RETURNING *',
    [username, role || "member"]
  );
  res.status(201).json(rows[0]);
}

export async function update(req, res) {
  const { rows: existingRows } = await db.query(
    'SELECT * FROM "user" WHERE id = $1',
    [req.params.id]
  );
  const existing = existingRows[0];
  if (!existing) return res.status(404).json({ error: "user not found" });

  const username = req.body.username ?? existing.username;
  const role = req.body.role ?? existing.role;

  const { rows } = await db.query(
    'UPDATE "user" SET username = $1, role = $2 WHERE id = $3 RETURNING *',
    [username, role, req.params.id]
  );
  res.json(rows[0]);
}

export async function remove(req, res, next) {
  try {
    const { rowCount } = await db.query('DELETE FROM "user" WHERE id = $1', [
      req.params.id,
    ]);
    if (rowCount === 0) return res.status(404).json({ error: "user not found" });
    res.status(204).end();
  } catch (err) {
    if (err.code === "23503") {
      return res
        .status(409)
        .json({ error: "cannot delete user: it is referenced elsewhere" });
    }
    next(err);
  }
}
