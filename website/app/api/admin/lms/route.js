import { NextResponse } from "next/server";

import { assertAdmin } from "../../../../lib/admin-auth";
import { db } from "../../../../lib/db";

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

const back = (request, query) =>
  NextResponse.redirect(new URL(`/admin/lms${query}`, request.url), 303);

export async function POST(request) {
  const unauthorized = await assertAdmin();
  if (unauthorized) return unauthorized;

  const form = await request.formData();
  const intent = text(form, "intent", 20);
  const id = Number(form.get("id") ?? 0);

  try {
    if (intent === "delete") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`delete from lms_courses where id = ${id}`;
      return back(request, "?saved=deleted");
    }

    if (intent === "publish" || intent === "unpublish") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update lms_courses set published = ${intent === "publish"} where id = ${id}
      `;
      return back(request, "?saved=status");
    }

    const title = text(form, "title", 180);
    if (title === "") return back(request, "?error=required");

    const level = text(form, "level", 80);
    const summary = text(form, "summary", 600);
    const topics = text(form, "topics", 600);
    const duration = text(form, "duration", 80);
    const link = text(form, "link", 1200);
    const position = Number(form.get("position") ?? 0) || 0;
    const published = form.get("published") === "on";

    if (intent === "update") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update lms_courses
        set title = ${title}, level = ${level}, summary = ${summary},
            topics = ${topics}, duration = ${duration}, link = ${link},
            position = ${position}, published = ${published}
        where id = ${id}
      `;
      return back(request, "?saved=updated");
    }

    await db()`
      insert into lms_courses
        (title, level, summary, topics, duration, link, position, published)
      values
        (${title}, ${level}, ${summary}, ${topics}, ${duration}, ${link},
         ${position}, ${published})
    `;
    return back(request, "?saved=created");
  } catch {
    return back(request, "?error=save");
  }
}
