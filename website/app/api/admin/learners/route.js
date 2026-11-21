import { NextResponse } from "next/server";

import { assertAdmin } from "../../../../lib/admin-auth";
import { db } from "../../../../lib/db";

const STAGES = ["signed_up", "learning", "paused", "completed"];

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

const back = (request, query) =>
  NextResponse.redirect(new URL(`/admin/learners${query}`, request.url), 303);

export async function POST(request) {
  const unauthorized = await assertAdmin();
  if (unauthorized) return unauthorized;

  const form = await request.formData();
  const intent = text(form, "intent", 20);
  const id = Number(form.get("id") ?? 0);
  const stage = text(form, "stage", 20);

  try {
    if (intent === "delete") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`delete from learners where id = ${id}`;
      return back(request, "?saved=deleted");
    }

    if (intent === "stage") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      if (!STAGES.includes(stage)) return back(request, "?error=stage");
      await db()`
        update learners
        set stage = ${stage}, updated_at = now()
        where id = ${id}
      `;
      return back(request, "?saved=stage");
    }

    const full_name = text(form, "full_name", 160);
    const email = text(form, "email", 200);
    if (full_name === "" || !email.includes("@")) return back(request, "?error=required");

    const phone = text(form, "phone", 60);
    const school = text(form, "school", 160);
    const programme = text(form, "programme", 120) || "Python for Beginners";
    const safeStage = STAGES.includes(stage) ? stage : "signed_up";
    const progress = Math.min(100, Math.max(0, Number(form.get("progress") ?? 0) || 0));
    const notes = text(form, "notes", 2000);

    if (intent === "update") {
      if (!Number.isInteger(id) || id <= 0) return back(request, "?error=missing");
      await db()`
        update learners
        set full_name = ${full_name}, email = ${email}, phone = ${phone},
            school = ${school}, programme = ${programme}, stage = ${safeStage},
            progress = ${progress}, notes = ${notes}, updated_at = now()
        where id = ${id}
      `;
      return back(request, "?saved=updated");
    }

    await db()`
      insert into learners
        (full_name, email, phone, school, programme, stage, progress, notes)
      values
        (${full_name}, ${email}, ${phone}, ${school}, ${programme},
         ${safeStage}, ${progress}, ${notes})
    `;
    return back(request, "?saved=created");
  } catch {
    return back(request, "?error=save");
  }
}
