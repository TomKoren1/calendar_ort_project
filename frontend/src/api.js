const BASE_URL = "/api";

async function request(path, options) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Request failed: ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

function makeResource(path) {
  return {
    list: () => request(`${path}`),
    get: (id) => request(`${path}/${id}`),
    create: (data) =>
      request(`${path}`, { method: "POST", body: JSON.stringify(data) }),
    update: (id, data) =>
      request(`${path}/${id}`, { method: "PUT", body: JSON.stringify(data) }),
    remove: (id) => request(`${path}/${id}`, { method: "DELETE" }),
  };
}

export const usersApi = makeResource("/users");
export const calendarsApi = makeResource("/calendars");
export const eventsApi = makeResource("/events");
export const tagsApi = makeResource("/tags");
