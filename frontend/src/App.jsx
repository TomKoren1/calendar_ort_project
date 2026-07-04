import { useEffect, useMemo, useState } from "react";
import "./App.css";
import { usersApi, calendarsApi, eventsApi, tagsApi } from "./api";
import CalendarGrid from "./components/CalendarGrid";
import EventModal from "./components/EventModal";
import Sidebar from "./components/Sidebar";

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

function App() {
  const today = new Date();
  const [year, setYear] = useState(today.getFullYear());
  const [month, setMonth] = useState(today.getMonth());

  const [users, setUsers] = useState([]);
  const [calendars, setCalendars] = useState([]);
  const [events, setEvents] = useState([]);
  const [tags, setTags] = useState([]);

  const [modalState, setModalState] = useState(null); // { event?, defaultDate }
  const [error, setError] = useState("");

  const loadAll = () => {
    usersApi.list().then(setUsers).catch((e) => setError(e.message));
    calendarsApi.list().then(setCalendars).catch((e) => setError(e.message));
    eventsApi.list().then(setEvents).catch((e) => setError(e.message));
    tagsApi.list().then(setTags).catch((e) => setError(e.message));
  };

  useEffect(loadAll, []);

  const tagsById = useMemo(
    () => Object.fromEntries(tags.map((t) => [t.id, t])),
    [tags]
  );

  const goPrevMonth = () => {
    if (month === 0) {
      setMonth(11);
      setYear((y) => y - 1);
    } else {
      setMonth((m) => m - 1);
    }
  };

  const goNextMonth = () => {
    if (month === 11) {
      setMonth(0);
      setYear((y) => y + 1);
    } else {
      setMonth((m) => m + 1);
    }
  };

  const goToday = () => {
    setYear(today.getFullYear());
    setMonth(today.getMonth());
  };

  const handleSaveEvent = async (data) => {
    try {
      if (modalState.event) {
        await eventsApi.update(modalState.event.id, data);
      } else {
        await eventsApi.create(data);
      }
      setModalState(null);
      loadAll();
    } catch (e) {
      setError(e.message);
    }
  };

  const handleDeleteEvent = async (id) => {
    try {
      await eventsApi.remove(id);
      setModalState(null);
      loadAll();
    } catch (e) {
      setError(e.message);
    }
  };

  const withErrorHandling = (fn) => async (...args) => {
    try {
      await fn(...args);
      loadAll();
    } catch (e) {
      setError(e.message);
    }
  };

  const addCalendar = withErrorHandling((name) => calendarsApi.create({ name }));
  const deleteCalendar = withErrorHandling((id) => calendarsApi.remove(id));
  const addTag = withErrorHandling((name, color) => tagsApi.create({ name, color }));
  const deleteTag = withErrorHandling((id) => tagsApi.remove(id));
  const addUser = withErrorHandling((username) => usersApi.create({ username }));
  const deleteUser = withErrorHandling((id) => usersApi.remove(id));

  return (
    <div className="app">
      <header className="app-header">
        <h1>📅 Calendar</h1>
        {error && (
          <div className="banner-error" onClick={() => setError("")}>
            {error} (click to dismiss)
          </div>
        )}
      </header>

      <div className="app-body">
        <main className="main-panel">
          <div className="calendar-toolbar">
            <div className="nav-buttons">
              <button className="btn ghost" onClick={goPrevMonth}>‹</button>
              <button className="btn ghost" onClick={goToday}>Today</button>
              <button className="btn ghost" onClick={goNextMonth}>›</button>
            </div>
            <h2>{MONTH_NAMES[month]} {year}</h2>
            <button
              className="btn primary"
              onClick={() =>
                setModalState({
                  defaultDate: `${year}-${String(month + 1).padStart(2, "0")}-${String(
                    today.getDate()
                  ).padStart(2, "0")}`,
                })
              }
            >
              + New Event
            </button>
          </div>

          <CalendarGrid
            year={year}
            month={month}
            events={events}
            tagsById={tagsById}
            onDayClick={(dateKey) => setModalState({ defaultDate: dateKey })}
            onEventClick={(event) => setModalState({ event, defaultDate: null })}
          />
        </main>

        <Sidebar
          calendars={calendars}
          tags={tags}
          users={users}
          onAddCalendar={addCalendar}
          onDeleteCalendar={deleteCalendar}
          onAddTag={addTag}
          onDeleteTag={deleteTag}
          onAddUser={addUser}
          onDeleteUser={deleteUser}
        />
      </div>

      {modalState && (
        <EventModal
          event={modalState.event}
          defaultDate={modalState.defaultDate}
          calendars={calendars}
          tags={tags}
          onSave={handleSaveEvent}
          onDelete={handleDeleteEvent}
          onClose={() => setModalState(null)}
        />
      )}
    </div>
  );
}

export default App;
