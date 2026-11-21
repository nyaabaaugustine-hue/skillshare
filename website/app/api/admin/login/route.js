import { NextResponse } from "next/server";

import {
  ADMIN_COOKIE,
  ADMIN_SESSION_MAX_AGE,
  createSessionToken,
  demoEnabled,
  passwordMatches,
} from "../../../../lib/admin-auth";

export async function POST(request) {
  const form = await request.formData();
  const intent = String(form.get("intent") ?? "");
  const password = String(form.get("password") ?? "");

  const allowed = intent === "demo" ? demoEnabled() : passwordMatches(password);

  if (!allowed) {
    return NextResponse.redirect(new URL("/admin/login?error=1", request.url), 303);
  }

  const response = NextResponse.redirect(new URL("/admin", request.url), 303);
  response.cookies.set(ADMIN_COOKIE, createSessionToken(), {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: ADMIN_SESSION_MAX_AGE,
  });
  return response;
}
