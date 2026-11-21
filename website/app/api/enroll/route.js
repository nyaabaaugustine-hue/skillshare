import { NextResponse } from "next/server";

import { db } from "../../../lib/db";

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

/**
 * The public "join the Python course" form. A signup lands in the admin
 * Learners list at the first stage; signing up twice with the same email just
 * refreshes the details rather than creating a duplicate.
 */
export async function POST(request) {
  const form = await request.formData();
  const full_name = text(form, "full_name", 160);
  const email = text(form, "email", 200);
  const phone = text(form, "phone", 60);
  const school = text(form, "school", 160);
  const programme = text(form, "programme", 120) || "Python for Beginners";

  if (full_name === "" || !email.includes("@")) {
    return NextResponse.redirect(
      new URL("/?course=error#featured-course", request.url),
      303,
    );
  }

  try {
    const existing = await db()`
      select id from learners where lower(email) = ${email.toLowerCase()} limit 1
    `;

    if (existing.length > 0) {
      await db()`
        update learners
        set full_name = ${full_name}, phone = ${phone}, school = ${school},
            programme = ${programme}, updated_at = now()
        where id = ${existing[0].id}
      `;
    } else {
      await db()`
        insert into learners (full_name, email, phone, school, programme, stage)
        values (${full_name}, ${email}, ${phone}, ${school}, ${programme}, 'signed_up')
      `;
    }
  } catch {
    return NextResponse.redirect(
      new URL("/?course=error#featured-course", request.url),
      303,
    );
  }

  return NextResponse.redirect(
    new URL("/?course=joined#featured-course", request.url),
    303,
  );
}
