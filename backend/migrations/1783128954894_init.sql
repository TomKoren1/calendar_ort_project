-- Up Migration

CREATE TABLE "user" (
  id SERIAL PRIMARY KEY,
  username TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE calendar (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE tag (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT
);

CREATE TABLE event (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  start_datetime TIMESTAMP NOT NULL,
  end_datetime TIMESTAMP NOT NULL,
  calendar_id INTEGER REFERENCES calendar(id),
  tag_id INTEGER REFERENCES tag(id)
);

CREATE TABLE user_calendar (
  user_id INTEGER NOT NULL REFERENCES "user"(id),
  calendar_id INTEGER NOT NULL REFERENCES calendar(id),
  PRIMARY KEY (user_id, calendar_id)
);

CREATE TABLE participant (
  event_id INTEGER NOT NULL REFERENCES event(id),
  user_id INTEGER NOT NULL REFERENCES "user"(id),
  PRIMARY KEY (event_id, user_id)
);

CREATE TABLE notification (
  id SERIAL PRIMARY KEY,
  method TEXT NOT NULL,
  event_id INTEGER NOT NULL REFERENCES event(id),
  datetime TIMESTAMP NOT NULL
);

-- Down Migration

DROP TABLE IF EXISTS notification;
DROP TABLE IF EXISTS participant;
DROP TABLE IF EXISTS user_calendar;
DROP TABLE IF EXISTS event;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS calendar;
DROP TABLE IF EXISTS "user";
