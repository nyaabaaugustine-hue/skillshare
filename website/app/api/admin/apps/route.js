import { NextResponse } from "next/server";

import { assertAdmin } from "../../../../lib/admin-auth";
import { db } from "../../../../lib/db";

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

const back = (request, query) =>
  NextResponse.redirect(new URL(`/admin/apps${query}`, request.url), 303);

export async function POST(request) {
  const unauthorized = await assertAdmin();
  if (unauthorized) return unauthorized;

  const form = await request.formData();
  const intent = text(form, "intent", 20);
  const id = Number(form.get("id") ?? 0);

  try {
    if (intent === "delete") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`delete from pwa_apps where id = ${id}`;
      return back(request, "?saved=deleted");
    }

    if (intent === "publish" || intent === "unpublish") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update pwa_apps set published = ${intent === "publish"} where id = ${id}
      `;
      return back(request, "?saved=status");
    }

    const name = text(form, "name", 160);
    if (name === "") return back(request, "?error=required");

    const category = text(form, "category", 80);
    const description = text(form, "description", 600);
    const url = text(form, "url", 1200);
    const icon = text(form, "icon", 1200);
    const position = Number(form.get("position") ?? 0) || 0;
    const published = form.get("published") === "on";

    if (intent === "update") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update pwa_apps
        set name = ${name}, category = ${category}, description = ${description},
            url = ${url}, icon = ${icon}, position = ${position},
            published = ${published}
        where id = ${id}
      `;
      return back(request, "?saved=updated");
    }

    await db()`
      insert into pwa_apps
        (name, category, description, url, icon, position, published)
      values
        (${name}, ${category}, ${description}, ${url}, ${icon}, ${position},
         ${published})
    `;
    return back(request, "?saved=created");
  } catch {
    return back(request, "?error=save");
  }
}
