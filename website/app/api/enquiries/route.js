import { NextResponse } from "next/server";

import { db } from "../../../lib/db";

const FORMSPREE_ENDPOINT = "https://formspree.io/f/maeodqly";

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

/**
 * The public "Register your school" form posts here instead of straight to
 * Formspree, so every enquiry is stored for the admin dashboard. The same
 * details are forwarded to Formspree afterwards, so the email notification the
 * team already relies on keeps arriving.
 */
export async function POST(request) {
  const form = await request.formData();
  const enquiry = {
    school_name: text(form, "school_name", 160),
    school_location: text(form, "school_location", 160),
    contact_name: text(form, "contact_name", 160),
    email: text(form, "email", 200),
    phone: text(form, "phone", 60),
    learner_count: text(form, "learner_count", 40),
    programme_interest: text(form, "programme_interest", 80),
    message: text(form, "message", 2000),
  };

  const required = ["school_name", "school_location", "contact_name", "email"];
  const missing = required.some((key) => enquiry[key] === "");
  if (missing || !enquiry.email.includes("@")) {
    return NextResponse.redirect(
      new URL("/?school=error#school-registration", request.url),
      303,
    );
  }

  try {
    await db()`
      insert into school_enquiries
        (school_name, school_location, contact_name, email, phone,
         learner_count, programme_interest, message)
      values
        (${enquiry.school_name}, ${enquiry.school_location}, ${enquiry.contact_name},
         ${enquiry.email}, ${enquiry.phone}, ${enquiry.learner_count},
         ${enquiry.programme_interest}, ${enquiry.message})
    `;
  } catch {
    return NextResponse.redirect(
      new URL("/?school=error#school-registration", request.url),
      303,
    );
  }

  // Notification only: a Formspree outage must not lose the stored enquiry.
  void fetch(FORMSPREE_ENDPOINT, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({
      _subject: "School registration enquiry - SkillBridge",
      ...enquiry,
    }),
  }).catch(() => {});

  return NextResponse.redirect(
    new URL("/?school=received#school-registration", request.url),
    303,
  );
}
