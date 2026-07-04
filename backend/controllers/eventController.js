import db from "../db.js";

export async function list(req, res) {
  const { rows } = await db.query(
    "SELECT * FROM event ORDER BY start_datetime ASC"
  );
  res.json(rows);
}

export async function getOne(req, res) {
  const { rows } = await db.query("SELECT * FROM event WHERE id = $1", [
    req.params.id,
  ]);
  if (!rows[0]) return res.status(404).json({ error: "event not found" });
  res.json(rows[0]);
}

export async function create(req, res) {
  const { name, description, start_datetime, end_datetime, calendar_id, tag_id } =
    req.body;
  if (!name || !start_datetime || !end_datetime) {
    return res
      .status(400)
      .json({ error: "name, start_datetime and end_datetime are required" });
  }
  const { rows } = await db.query(
    `INSERT INTO event (name, description, start_datetime, end_datetime, calendar_id, tag_id)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [
      name,
      description || null,
      start_datetime,
      end_datetime,
      calendar_id ?? null,
      tag_id ?? null,
    ]
  );
  res.status(201).json(rows[0]);
}

export async function update(req, res) {
  const { rows: existingRows } = await db.query(
    "SELECT * FROM event WHERE id = $1",
    [req.params.id]
  );
  const existing = existingRows[0];
  if (!existing) return res.status(404).json({ error: "event not found" });

  const name = req.body.name ?? existing.name;
  const description = req.body.description ?? existing.description;
  const start_datetime = req.body.start_datetime ?? existing.start_datetime;
  const end_datetime = req.body.end_datetime ?? existing.end_datetime;
  const calendar_id = req.body.calendar_id ?? existing.calendar_id;
  const tag_id = req.body.tag_id ?? existing.tag_id;

  const { rows } = await db.query(
    `UPDATE event SET name = $1, description = $2, start_datetime = $3, end_datetime = $4,
     calendar_id = $5, tag_id = $6 WHERE id = $7 RETURNING *`,
    [name, description, start_datetime, end_datetime, calendar_id, tag_id, req.params.id]
  );
  res.json(rows[0]);
}

export async function remove(req, res, next) {
  try {
    const { rowCount } = await db.query("DELETE FROM event WHERE id = $1", [
      req.params.id,
    ]);
    if (rowCount === 0) return res.status(404).json({ error: "event not found" });
    res.status(204).end();
  } catch (err) {
    if (err.code === "23503") {
      return res
        .status(409)
        .json({ error: "cannot delete event: it is referenced elsewhere" });
    }
    next(err);
  }
}
