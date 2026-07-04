import db from "../db.js";

export async function list(req, res) {
  const { rows } = await db.query("SELECT * FROM calendar ORDER BY id DESC");
  res.json(rows);
}

export async function getOne(req, res) {
  const { rows } = await db.query("SELECT * FROM calendar WHERE id = $1", [
    req.params.id,
  ]);
  if (!rows[0]) return res.status(404).json({ error: "calendar not found" });
  res.json(rows[0]);
}

export async function create(req, res) {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: "name is required" });
  }
  const { rows } = await db.query(
    "INSERT INTO calendar (name) VALUES ($1) RETURNING *",
    [name]
  );
  res.status(201).json(rows[0]);
}

export async function update(req, res) {
  const { rows: existingRows } = await db.query(
    "SELECT * FROM calendar WHERE id = $1",
    [req.params.id]
  );
  const existing = existingRows[0];
  if (!existing) return res.status(404).json({ error: "calendar not found" });

  const name = req.body.name ?? existing.name;
  const { rows } = await db.query(
    "UPDATE calendar SET name = $1 WHERE id = $2 RETURNING *",
    [name, req.params.id]
  );
  res.json(rows[0]);
}

export async function remove(req, res, next) {
  try {
    const { rowCount } = await db.query("DELETE FROM calendar WHERE id = $1", [
      req.params.id,
    ]);
    if (rowCount === 0)
      return res.status(404).json({ error: "calendar not found" });
    res.status(204).end();
  } catch (err) {
    if (err.code === "23503") {
      return res
        .status(409)
        .json({ error: "cannot delete calendar: it is still used by an event" });
    }
    next(err);
  }
}
