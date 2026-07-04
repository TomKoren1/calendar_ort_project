import db from "../db.js";

export async function list(req, res) {
  const { rows } = await db.query("SELECT * FROM tag ORDER BY id DESC");
  res.json(rows);
}

export async function getOne(req, res) {
  const { rows } = await db.query("SELECT * FROM tag WHERE id = $1", [
    req.params.id,
  ]);
  if (!rows[0]) return res.status(404).json({ error: "tag not found" });
  res.json(rows[0]);
}

export async function create(req, res) {
  const { name, description, color } = req.body;
  if (!name) {
    return res.status(400).json({ error: "name is required" });
  }
  const { rows } = await db.query(
    "INSERT INTO tag (name, description, color) VALUES ($1, $2, $3) RETURNING *",
    [name, description || null, color || null]
  );
  res.status(201).json(rows[0]);
}

export async function update(req, res) {
  const { rows: existingRows } = await db.query(
    "SELECT * FROM tag WHERE id = $1",
    [req.params.id]
  );
  const existing = existingRows[0];
  if (!existing) return res.status(404).json({ error: "tag not found" });

  const name = req.body.name ?? existing.name;
  const description = req.body.description ?? existing.description;
  const color = req.body.color ?? existing.color;

  const { rows } = await db.query(
    "UPDATE tag SET name = $1, description = $2, color = $3 WHERE id = $4 RETURNING *",
    [name, description, color, req.params.id]
  );
  res.json(rows[0]);
}

export async function remove(req, res, next) {
  try {
    const { rowCount } = await db.query("DELETE FROM tag WHERE id = $1", [
      req.params.id,
    ]);
    if (rowCount === 0) return res.status(404).json({ error: "tag not found" });
    res.status(204).end();
  } catch (err) {
    if (err.code === "23503") {
      return res
        .status(409)
        .json({ error: "cannot delete tag: it is still used by an event" });
    }
    next(err);
  }
}
