import { NextResponse } from "next/server";

/**
 * Public contact popup. Forwards to the same Formspree form the school-enquiry
 * route uses (found in app/api/enquiries/route.js), but answers with JSON so
 * the popup can show its own success and error states instead of redirecting.
 */
const FORMSPREE_ENDPOINT = "https://formspree.io/f/maeodqly";

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

export async function POST(request) {
  let form;
  try {
    form = await request.formData();
  } catch {
    return NextResponse.json({ error: "That request could not be read." }, { status: 400 });
  }

  const enquiry = {
    name: text(form, "name", 160),
    email: text(form, "email", 200),
    phone: text(form, "phone", 60),
    enquiry_type: text(form, "enquiry_type", 80) || "General enquiry",
    programme: text(form, "programme", 160),
    message: text(form, "message", 2000),
  };

  if (enquiry.name === "" || !enquiry.email.includes("@")) {
    return NextResponse.json(
      { error: "A name and a valid email are required." },
      { status: 422 },
    );
  }

  try {
    const response = await fetch(FORMSPREE_ENDPOINT, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        _subject: `Website enquiry — ${enquiry.enquiry_type}`,
        _replyto: enquiry.email,
        ...enquiry,
      }),
    });

    if (!response.ok) {
      return NextResponse.json(
        { error: "The enquiry service refused that message." },
        { status: 502 },
      );
    }
  } catch {
    return NextResponse.json(
      { error: "The enquiry service is unreachable." },
      { status: 502 },
    );
  }

  return NextResponse.json({ ok: true });
}
