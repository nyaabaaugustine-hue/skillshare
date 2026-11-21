import { NextResponse } from "next/server";

import { assertAdmin } from "../../../../lib/admin-auth";
import { db } from "../../../../lib/db";

const ALLOWED = new Set(["new", "contacted", "closed"]);

export async function POST(request) {
  const unauthorized = await assertAdmin();
  if (unauthorized) return unauthorized;

  const form = await request.formData();
  const id = Number(form.get("id") ?? 0);
  const status = String(form.get("status") ?? "");
  const intent = String(form.get("intent") ?? "");

  try {
    if (intent === "delete") {
      if (!Number.isInteger(id) || id <= 0) {
        return NextResponse.redirect(new URL("/admin/enquiries?error=missing", request.url), 303);
      }
      await db()`delete from school_enquiries where id = ${id}`;
      return NextResponse.redirect(
        new URL("/admin/enquiries?saved=deleted", request.url),
        303,
      );
    }

    if (!ALLOWED.has(status) || !Number.isInteger(id) || id <= 0) {
      return NextResponse.redirect(new URL("/admin/enquiries?error=bad", request.url), 303);
    }
    await db()`update school_enquiries set status = ${status} where id = ${id}`;
    return NextResponse.redirect(
      new URL("/admin/enquiries?saved=status", request.url),
      303,
    );
  } catch {
    return NextResponse.redirect(new URL("/admin/enquiries?error=save", request.url), 303);
  }
}
