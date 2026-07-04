import { useState } from "react";

function ManageList({ title, items, renderItem, onAdd, addFields }) {
  const [values, setValues] = useState(
    Object.fromEntries(addFields.map((f) => [f.name, ""]))
  );

  const handleAdd = (e) => {
    e.preventDefault();
    const requiredFilled = addFields
      .filter((f) => f.required)
      .every((f) => values[f.name]);
    if (!requiredFilled) return;
    onAdd(values);
    setValues(Object.fromEntries(addFields.map((f) => [f.name, ""])));
  };

  return (
    <div className="manage-section">
      <h3>{title}</h3>
      <form onSubmit={handleAdd} className="manage-form">
        {addFields.map((f) => (
          <input
            key={f.name}
            type={f.type || "text"}
            placeholder={f.placeholder}
            value={values[f.name]}
            onChange={(e) =>
              setValues((v) => ({ ...v, [f.name]: e.target.value }))
            }
          />
        ))}
        <button type="submit" className="btn primary small">
          Add
        </button>
      </form>
      <ul className="manage-list">
        {items.map((item) => (
          <li key={item.id}>{renderItem(item)}</li>
        ))}
      </ul>
    </div>
  );
}

export default function Sidebar({
  calendars,
  tags,
  users,
  onAddCalendar,
  onDeleteCalendar,
  onAddTag,
  onDeleteTag,
  onAddUser,
  onDeleteUser,
}) {
  return (
    <aside className="sidebar">
      <ManageList
        title="Calendars"
        items={calendars}
        addFields={[{ name: "name", placeholder: "Calendar name", required: true }]}
        onAdd={(v) => onAddCalendar(v.name)}
        renderItem={(c) => (
          <div className="manage-row">
            <span>{c.name}</span>
            <button className="btn ghost small" onClick={() => onDeleteCalendar(c.id)}>
              ✕
            </button>
          </div>
        )}
      />

      <ManageList
        title="Tags"
        items={tags}
        addFields={[
          { name: "name", placeholder: "Tag name", required: true },
          { name: "color", placeholder: "#color", type: "color" },
        ]}
        onAdd={(v) => onAddTag(v.name, v.color || "#5b8def")}
        renderItem={(t) => (
          <div className="manage-row">
            <span>
              <span className="color-dot" style={{ background: t.color || "#5b8def" }} />
              {t.name}
            </span>
            <button className="btn ghost small" onClick={() => onDeleteTag(t.id)}>
              ✕
            </button>
          </div>
        )}
      />

      <ManageList
        title="Users"
        items={users}
        addFields={[{ name: "username", placeholder: "Username", required: true }]}
        onAdd={(v) => onAddUser(v.username)}
        renderItem={(u) => (
          <div className="manage-row">
            <span>{u.username}</span>
            <button className="btn ghost small" onClick={() => onDeleteUser(u.id)}>
              ✕
            </button>
          </div>
        )}
      />
    </aside>
  );
}
