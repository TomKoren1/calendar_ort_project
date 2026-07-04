import { useEffect, useState } from "react";
import { toDatetimeLocal } from "../dateUtils";

export default function EventModal({ event, defaultDate, calendars, tags, onSave, onDelete, onClose }) {
  const isEditing = Boolean(event);
  const [name, setName] = useState(event?.name || "");
  const [description, setDescription] = useState(event?.description || "");
  const [startDatetime, setStartDatetime] = useState(
    toDatetimeLocal(event?.start_datetime) || toDatetimeLocal(`${defaultDate}T09:00`)
  );
  const [endDatetime, setEndDatetime] = useState(
    toDatetimeLocal(event?.end_datetime) || toDatetimeLocal(`${defaultDate}T10:00`)
  );
  const [calendarId, setCalendarId] = useState(event?.calendar_id || "");
  const [tagId, setTagId] = useState(event?.tag_id || "");
  const [error, setError] = useState("");

  useEffect(() => {
    const onKey = (e) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!name || !startDatetime || !endDatetime) {
      setError("Name, start and end are required.");
      return;
    }
    if (new Date(endDatetime) < new Date(startDatetime)) {
      setError("End must be after start.");
      return;
    }
    onSave({
      name,
      description,
      start_datetime: startDatetime,
      end_datetime: endDatetime,
      calendar_id: calendarId || null,
      tag_id: tagId || null,
    });
  };

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <h2>{isEditing ? "Edit Event" : "New Event"}</h2>
        <form onSubmit={handleSubmit}>
          <label>
            Name
            <input value={name} onChange={(e) => setName(e.target.value)} autoFocus />
          </label>
          <label>
            Description
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
            />
          </label>
          <div className="modal-row">
            <label>
              Start
              <input
                type="datetime-local"
                value={startDatetime}
                onChange={(e) => setStartDatetime(e.target.value)}
              />
            </label>
            <label>
              End
              <input
                type="datetime-local"
                value={endDatetime}
                onChange={(e) => setEndDatetime(e.target.value)}
              />
            </label>
          </div>
          <div className="modal-row">
            <label>
              Calendar
              <select value={calendarId} onChange={(e) => setCalendarId(e.target.value)}>
                <option value="">None</option>
                {calendars.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Tag
              <select value={tagId} onChange={(e) => setTagId(e.target.value)}>
                <option value="">None</option>
                {tags.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name}
                  </option>
                ))}
              </select>
            </label>
          </div>

          {error && <p className="error">{error}</p>}

          <div className="modal-actions">
            {isEditing && (
              <button
                type="button"
                className="btn danger"
                onClick={() => onDelete(event.id)}
              >
                Delete
              </button>
            )}
            <div className="spacer" />
            <button type="button" className="btn ghost" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn primary">
              Save
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
