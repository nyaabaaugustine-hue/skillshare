import { NextResponse } from "next/server";

import { assertAdmin } from "../../../../lib/admin-auth";
import { db } from "../../../../lib/db";

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

const back = (request, query) =>
  NextResponse.redirect(new URL(`/admin/news${query}`, request.url), 303);

export async function POST(request) {
  const unauthorized = await assertAdmin();
  if (unauthorized) return unauthorized;

  const form = await request.formData();
  const intent = text(form, "intent", 20);
  const id = Number(form.get("id") ?? 0);

  try {
    if (intent === "delete") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`delete from news_posts where id = ${id}`;
      return back(request, "?saved=deleted");
    }

    if (intent === "publish" || intent === "unpublish") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update news_posts set published = ${intent === "publish"} where id = ${id}
      `;
      return back(request, "?saved=status");
    }

    const title = text(form, "title", 180);
    if (title === "") return back(request, "?error=required");

    const excerpt = text(form, "excerpt", 400);
    const image = text(form, "image", 1200);
    const body = text(form, "body", 6000);
    const published = form.get("published") === "on";

    if (intent === "update") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update news_posts
        set title = ${title}, excerpt = ${excerpt}, image = ${image},
            body = ${body}, published = ${published}
        where id = ${id}
      `;
      return back(request, "?saved=updated");
    }

    await db()`
      insert into news_posts (title, excerpt, image, body, published)
      values (${title}, ${excerpt}, ${image}, ${body}, ${published})
    `;
    return back(request, "?saved=created");
  } catch {
    return back(request, "?error=save");
  }
}
