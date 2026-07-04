import { WEEKDAYS, buildMonthGrid, toDateKey } from "../dateUtils";

export default function CalendarGrid({ year, month, events, tagsById, onDayClick, onEventClick }) {
  const days = buildMonthGrid(year, month);
  const todayKey = toDateKey(new Date());

  const eventsByDay = {};
  for (const ev of events) {
    const key = toDateKey(ev.start_datetime);
    (eventsByDay[key] ||= []).push(ev);
  }

  return (
    <div className="calendar-grid">
      {WEEKDAYS.map((wd) => (
        <div key={wd} className="weekday-label">
          {wd}
        </div>
      ))}
      {days.map((date) => {
        const key = toDateKey(date);
        const inMonth = date.getMonth() === month;
        const dayEvents = eventsByDay[key] || [];
        return (
          <div
            key={key}
            className={`day-cell ${inMonth ? "" : "outside"} ${
              key === todayKey ? "today" : ""
            }`}
            onClick={() => onDayClick(key)}
          >
            <div className="day-number">{date.getDate()}</div>
            <div className="day-events">
              {dayEvents.slice(0, 3).map((ev) => {
                const tag = tagsById[ev.tag_id];
                return (
                  <div
                    key={ev.id}
                    className="event-pill"
                    style={{ background: tag?.color || "#5b8def" }}
                    onClick={(e) => {
                      e.stopPropagation();
                      onEventClick(ev);
                    }}
                    title={ev.name}
                  >
                    {ev.name}
                  </div>
                );
              })}
              {dayEvents.length > 3 && (
                <div className="event-more">+{dayEvents.length - 3} more</div>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
