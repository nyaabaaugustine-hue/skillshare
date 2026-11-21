import { NextResponse } from "next/server";

import { assertAdmin } from "../../../../lib/admin-auth";
import { db } from "../../../../lib/db";

const ROLES = ["LEARNER", "PARENT", "ADMIN"];
const STATUSES = ["active", "suspended", "deactivated"];
const RELATIONSHIPS = ["guardian", "parent", "sponsor"];
const UUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

const text = (form, key, max = 400) =>
  String(form.get(key) ?? "").trim().slice(0, max);

const back = (request, query) =>
  NextResponse.redirect(new URL(`/admin/students${query}`, request.url), 303);

/** The account must exist in the learner app's auth table; never trust the form alone. */
async function findAccount(userId) {
  if (!UUID.test(userId)) return null;
  const rows = await db()`
    select id::text as id, email, coalesce(nullif(name, ''), email) as name
    from neon_auth."user"
    where id = ${userId}::uuid
    limit 1
  `;
  return rows[0] ?? null;
}

/** Create the LMS profile row on first use, then update it. */
async function saveProfile(account, patch) {
  const rows = await db()`
    select role, status from app_users where user_id = ${account.id} limit 1
  `;
  const current = rows[0] ?? { role: "LEARNER", status: "active" };
  const role = ROLES.includes(patch.role) ? patch.role : current.role;
  const status = STATUSES.includes(patch.status) ? patch.status : current.status;

  await db()`
    insert into app_users (user_id, email, display_name, role, status)
    values (${account.id}, ${account.email}, ${account.name}, ${role}, ${status})
    on conflict (user_id) do update
      set email = excluded.email,
          display_name = coalesce(excluded.display_name, app_users.display_name),
          role = excluded.role,
          status = excluded.status,
          updated_at = now()
  `;

  return { role, status };
}

async function audit(action, entityId, metadata) {
  await db()`
    insert into audit_log (actor_user_id, action, entity_type, entity_id, metadata)
    values (
      'admin-dashboard',
      ${action},
      'app_user',
      ${entityId},
      ${JSON.stringify(metadata)}::jsonb
    )
  `;
}

/**
 * Suspension has to reach the auth layer as well as the profile row, otherwise
 * the account keeps its session. Better Auth's `banned` flag is the switch the
 * app checks when signing in.
 */
async function syncBan(account, status) {
  try {
    await db()`
      update neon_auth."user"
      set banned = ${status !== "active"},
          "banReason" = ${
            status === "active" ? null : `Suspended by the SkillBridge admin (${status}).`
          }::text,
          "banExpires" = null,
          "updatedAt" = now()
      where id = ${account.id}::uuid
    `;
  } catch {
    // The profile row still changed; the ban flag is best effort.
  }
}

export async function POST(request) {
  const unauthorized = await assertAdmin();
  if (unauthorized) return unauthorized;

  const form = await request.formData();
  const intent = text(form, "intent", 20);
  const userId = text(form, "user_id", 64);

  try {
    const account = await findAccount(userId);
    if (!account) return back(request, "?error=missing");

    if (intent === "status" || intent === "profile") {
      const status = text(form, "status", 20);
      if (status !== "" && !STATUSES.includes(status)) return back(request, "?error=status");
      const role = text(form, "role", 20);
      if (role !== "" && !ROLES.includes(role)) return back(request, "?error=role");

      const saved = await saveProfile(account, { status, role });
      await syncBan(account, saved.status);
      await audit("student.profile", account.id, {
        email: account.email,
        role: saved.role,
        status: saved.status,
      });
      return back(request, "?saved=profile");
    }

    if (intent === "link") {
      const email = text(form, "parent_email", 200).toLowerCase();
      const requested = text(form, "relationship", 20);
      const relationship = RELATIONSHIPS.includes(requested) ? requested : "guardian";
      if (!email.includes("@")) return back(request, "?error=guardian");

      const parents = await db()`
        select id::text as id, email, coalesce(nullif(name, ''), email) as name
        from neon_auth."user"
        where lower(email) = ${email}
        limit 1
      `;
      const parent = parents[0];
      if (!parent) return back(request, "?error=guardian");
      if (parent.id === account.id) return back(request, "?error=self");

      await saveProfile(parent, { role: "PARENT" });

      const existing = await db()`
        select id from parent_learner
        where parent_user_id = ${parent.id} and learner_user_id = ${account.id}
        limit 1
      `;

      if (existing.length > 0) {
        await db()`
          update parent_learner
          set status = 'active', relationship = ${relationship}, updated_at = now()
          where id = ${existing[0].id}
        `;
      } else {
        await db()`
          insert into parent_learner (parent_user_id, learner_user_id, relationship, status)
          values (${parent.id}, ${account.id}, ${relationship}, 'active')
        `;
      }

      await audit("guardian.link", account.id, { parent: parent.email, relationship });
      return back(request, "?saved=guardian");
    }

    if (intent === "unlink") {
      const linkId = text(form, "link_id", 64);
      if (linkId === "") return back(request, "?error=missing");
      await db()`
        delete from parent_learner
        where id = ${linkId} and learner_user_id = ${account.id}
      `;
      await audit("guardian.unlink", account.id, { link: linkId });
      return back(request, "?saved=guardian");
    }

    return back(request, "?error=missing");
  } catch {
    return back(request, "?error=save");
  }
}
