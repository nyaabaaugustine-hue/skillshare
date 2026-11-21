import { NextResponse } from "next/server";

import { assertAdmin } from "../../../../lib/admin-auth";
import { db } from "../../../../lib/db";

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

const back = (request, query) =>
  NextResponse.redirect(new URL(`/admin/team${query}`, request.url), 303);

export async function POST(request) {
  const unauthorized = await assertAdmin();
  if (unauthorized) return unauthorized;

  const form = await request.formData();
  const intent = text(form, "intent", 20);
  const id = Number(form.get("id") ?? 0);

  try {
    if (intent === "delete") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`delete from team_members where id = ${id}`;
      return back(request, "?saved=deleted");
    }

    const name = text(form, "name", 120);
    const role = text(form, "role", 160);
    if (name === "" || role === "") return back(request, "?error=required");

    const focus = text(form, "focus", 120);
    const image = text(form, "image", 1200);
    const bio = text(form, "bio", 1200);
    const position = Number(form.get("position") ?? 0) || 0;
    const published = form.get("published") === "on";

    if (intent === "update") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update team_members
        set name = ${name}, role = ${role}, focus = ${focus}, image = ${image},
            bio = ${bio}, position = ${position}, published = ${published}
        where id = ${id}
      `;
      return back(request, "?saved=updated");
    }

    await db()`
      insert into team_members (name, role, focus, image, bio, position, published)
      values (${name}, ${role}, ${focus}, ${image}, ${bio}, ${position}, ${published})
    `;
    return back(request, "?saved=created");
  } catch {
    return back(request, "?error=save");
  }
}
