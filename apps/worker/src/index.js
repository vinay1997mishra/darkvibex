import { normalizeRole } from "./role_policy.js";

const json = (data, init = {}) =>
  new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "darkvibex-api",
        db_bound: Boolean(env.DB),
        files_bound: Boolean(env.FILES),
      });
    }

    if (url.pathname === "/api/roles/validate" && request.method === "POST") {
      try {
        const body = await request.json();
        return json({ ok: true, role: normalizeRole(body?.role) });
      } catch (error) {
        return json(
          { ok: false, error: String(error?.message ?? error) },
          { status: 400 },
        );
      }
    }

    return json({ ok: false, error: "not_found" }, { status: 404 });
  },
};
