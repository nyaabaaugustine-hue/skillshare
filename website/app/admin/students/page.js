import { requireAdmin } from "../../../lib/admin-auth";
import { db } from "../../../lib/db";

export const dynamic = "force-dynamic";

const ROLES = [
  { value: "LEARNER", label: "Learner" },
  { value: "PARENT", label: "Parent / guardian" },
  { value: "ADMIN", label: "Admin" },
];

const STATUSES = [
  { value: "active", label: "Active" },
  { value: "suspended", label: "Suspended" },
  { value: "deactivated", label: "Deactivated" },
];

const RELATIONSHIPS = ["guardian", "parent", "sponsor"];

const roleLabel = (value) => ROLES.find((role) => role.value === value)?.label ?? "Learner";
const statusLabel = (value) => STATUSES.find((status) => status.value === value)?.label ?? value;

const day = (value) =>
  value
    ? new Intl.DateTimeFormat("en-GB", {
        day: "2-digit",
        month: "short",
        year: "numeric",
      }).format(new Date(value))
    : "—";

const moment = (value) =>
  value
    ? new Intl.DateTimeFormat("en-GB", {
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      }).format(new Date(value))
    : "never";

const ERRORS = {
  guardian: "No account uses that email. Ask the guardian to register in the app first.",
  self: "A learner cannot be their own guardian.",
  status: "That status is not recognised.",
  role: "That role is not recognised.",
  missing: "That account could not be found.",
  save: "That change did not save. Please try again.",
};

function QuickStatus({ student }) {
  return (
    <div className="admin-actions">
      {STATUSES.filter((status) => status.value !== student.status).map((status) => (
        <form action="/api/admin/students" method="post" key={status.value}>
          <input type="hidden" name="intent" value="status" />
          <input type="hidden" name="user_id" value={student.user_id} />
          <input type="hidden" name="status" value={status.value} />
          <button
            type="submit"
            className={`admin-button ${
              status.value === "active" ? "admin-button-quiet" : "admin-button-danger"
            }`}
          >
            {status.value === "active"
              ? "Reactivate"
              : status.value === "suspended"
                ? "Suspend"
                : "Deactivate"}
          </button>
        </form>
      ))}
    </div>
  );
}

export default async function AdminStudentsPage({ searchParams }) {
  await requireAdmin();
  const params = await searchParams;
  const q = String(params?.q ?? "").trim().slice(0, 120);
  const like = `%${q}%`;

  let students = [];
  let stats = { total: 0, suspended: 0, learning: 0, steps: 0, active_sessions: 0 };
  let activity = [];
  let unavailable = false;

  try {
    students = await db()`
      select
        u.id::text as user_id,
        coalesce(nullif(u.name, ''), split_part(u.email, '@', 1)) as name,
        u.email,
        u."emailVerified" as email_verified,
        u.banned,
        u."createdAt" as joined_at,
        coalesce(p.role, 'LEARNER') as role,
        coalesce(p.status, case when u.banned then 'suspended' else 'active' end) as status,
        p.user_id is not null as has_profile,
        p.last_seen_at,
        coalesce(b.steps_completed, 0) as steps,
        coalesce(b.practices_completed, 0) as practices,
        coalesce(b.score_total, 0) as score,
        s.last_seen_at as last_session_at,
        (
          select count(*)::int from parent_learner pl
          where pl.learner_user_id = u.id::text and pl.status <> 'revoked'
        ) as guardians,
        coalesce(
          (
            select json_agg(
              json_build_object(
                'id', pl.id,
                'name', coalesce(pu.display_name, pl.parent_user_id),
                'email', pu.email,
                'relationship', pl.relationship,
                'status', pl.status
              )
              order by pl.created_at
            )
            from parent_learner pl
            left join app_users pu on pu.user_id = pl.parent_user_id
            where pl.learner_user_id = u.id::text and pl.status <> 'revoked'
          ),
          '[]'::json
        ) as guardian_links
      from neon_auth."user" u
      left join app_users p on p.user_id = u.id::text
      left join leaderboard_entries b on b.id = 'web:' || u.id::text
      left join (
        select "userId"::text as uid, max("createdAt") as last_seen_at
        from neon_auth.session
        group by 1
      ) s on s.uid = u.id::text
      where ${q} = ''
         or coalesce(u.name, '') ilike ${like}
         or u.email ilike ${like}
      order by coalesce(p.last_seen_at, s.last_seen_at, u."createdAt") desc
      limit 200
    `;

    const [summary] = await db()`
      select
        (select count(*)::int from neon_auth."user") as total,
        (select count(*)::int from app_users where status <> 'active') as suspended,
        (
          select count(*)::int from leaderboard_entries
          where steps_completed > 0 or practices_completed > 0 or score_total > 0
        ) as learning,
        (select coalesce(sum(steps_completed), 0)::int from leaderboard_entries) as steps,
        (select count(*)::int from neon_auth.session where "expiresAt" > now()) as active_sessions
    `;
    stats = summary ?? stats;

    activity = await db()`
      select id, action, entity_id, metadata, created_at
      from audit_log
      order by created_at desc
      limit 6
    `;
  } catch {
    unavailable = true;
  }

  const error = params?.error ? ERRORS[String(params.error)] ?? ERRORS.save : null;

  return (
    <>
      <header className="admin-head">
        <h1>LMS students</h1>
        <p>
          Accounts on the learner app — who registered, who is learning, and who can sign in.
          Suspending an account blocks sign-in until it is reactivated.
        </p>
      </header>

      {params?.saved ? (
        <p className="admin-alert admin-alert-ok" role="status">
          Saved. The learner app shows this change on the next sign-in.
        </p>
      ) : null}
      {error ? (
        <p className="admin-alert admin-alert-error" role="alert">
          {error}
        </p>
      ) : null}
      {unavailable ? (
        <p className="admin-alert admin-alert-error" role="alert">
          The LMS account tables are not reachable from this database. Run{" "}
          <code>npm run db:install</code> once Neon Auth is enabled for the project.
        </p>
      ) : null}

      <section className="admin-stats" aria-label="Platform accounts">
        <article className="admin-stat">
          <span>Registered accounts</span>
          <strong>{stats.total}</strong>
          <small>{stats.active_sessions} active sessions</small>
        </article>
        <article className="admin-stat">
          <span>Learning now</span>
          <strong>{stats.learning}</strong>
          <small>{stats.steps} steps completed</small>
        </article>
        <article className="admin-stat">
          <span>Suspended</span>
          <strong>{stats.suspended}</strong>
          <small>Blocked from signing in</small>
        </article>
      </section>

      <section className="admin-panel">
        <div className="admin-panel-head">
          <h2>Students ({students.length})</h2>
          <a className="admin-text-link" href="https://academy-skillshare.vercel.app/app/index.html?v=2" target="_blank" rel="noreferrer">
            Open learner app ↗
          </a>
        </div>

        <form action="/admin/students" method="get" className="admin-search">
          <input
            type="search"
            name="q"
            defaultValue={q}
            placeholder="Search by name or email"
            aria-label="Search students"
          />
          <button type="submit" className="admin-button">Search</button>
          {q ? <a className="admin-text-link" href="/admin/students">Clear</a> : null}
        </form>

        {students.length === 0 ? (
          <p className="admin-empty">
            {unavailable
              ? "No account data available."
              : q
                ? `No account matches “${q}”.`
                : "Nobody has registered in the learner app yet. New sign-ups appear here."}
          </p>
        ) : (
          <ul className="admin-list">
            {students.map((student) => (
              <li key={student.user_id} className="admin-record">
                <div className="admin-record-head">
                  <div>
                    <h3>{student.name}</h3>
                    <p className="admin-record-meta">
                      <a href={`mailto:${student.email}`}>{student.email}</a>
                      {student.email_verified ? " · verified" : " · unverified"}
                    </p>
                  </div>
                  <div className="admin-pill-group">
                    <span className={`admin-pill admin-pill-${student.role.toLowerCase()}`}>
                      {roleLabel(student.role)}
                    </span>
                    <span className={`admin-pill admin-pill-${student.status}`}>
                      {statusLabel(student.status)}
                    </span>
                  </div>
                </div>

                <p className="admin-record-meta">
                  Joined {day(student.joined_at)} · last active{" "}
                  {moment(student.last_session_at ?? student.last_seen_at)} · {student.steps} steps ·{" "}
                  {student.practices} practices · {student.score} points
                </p>

                {!student.has_profile ? (
                  <p className="admin-record-meta">
                    No LMS profile yet — the first role or status change here creates one.
                  </p>
                ) : null}

                {student.guardian_links.length > 0 ? (
                  <ul className="admin-guardians">
                    {student.guardian_links.map((link) => (
                      <li key={link.id}>
                        <span>
                          <strong>{link.name}</strong>
                          {link.email ? <> · {link.email}</> : null} · {link.relationship} ·{" "}
                          {link.status}
                        </span>
                        <form action="/api/admin/students" method="post">
                          <input type="hidden" name="intent" value="unlink" />
                          <input type="hidden" name="user_id" value={student.user_id} />
                          <input type="hidden" name="link_id" value={link.id} />
                          <button type="submit" className="admin-link-button">
                            Unlink
                          </button>
                        </form>
                      </li>
                    ))}
                  </ul>
                ) : null}

                <QuickStatus student={student} />

                <details className="admin-details">
                  <summary>Change role, status or guardian</summary>

                  <form action="/api/admin/students" method="post" className="admin-form">
                    <input type="hidden" name="intent" value="profile" />
                    <input type="hidden" name="user_id" value={student.user_id} />
                    <div className="admin-grid">
                      <label className="admin-field">
                        <span>Role</span>
                        <select name="role" defaultValue={student.role}>
                          {ROLES.map((role) => (
                            <option key={role.value} value={role.value}>{role.label}</option>
                          ))}
                        </select>
                      </label>
                      <label className="admin-field">
                        <span>Status</span>
                        <select name="status" defaultValue={student.status}>
                          {STATUSES.map((status) => (
                            <option key={status.value} value={status.value}>{status.label}</option>
                          ))}
                        </select>
                      </label>
                    </div>
                    <button type="submit" className="admin-button admin-button-primary">
                      Save account
                    </button>
                  </form>

                  <form action="/api/admin/students" method="post" className="admin-form">
                    <input type="hidden" name="intent" value="link" />
                    <input type="hidden" name="user_id" value={student.user_id} />
                    <div className="admin-grid">
                      <label className="admin-field">
                        <span>Guardian email</span>
                        <input name="parent_email" type="email" placeholder="parent@example.com" maxLength={200} />
                      </label>
                      <label className="admin-field">
                        <span>Relationship</span>
                        <select name="relationship" defaultValue="guardian">
                          {RELATIONSHIPS.map((relationship) => (
                            <option key={relationship} value={relationship}>{relationship}</option>
                          ))}
                        </select>
                      </label>
                    </div>
                    <button type="submit" className="admin-button">
                      Link guardian account
                    </button>
                  </form>
                </details>
              </li>
            ))}
          </ul>
        )}
      </section>

      {activity.length > 0 ? (
        <section className="admin-panel">
          <h2>Recent account activity</h2>
          <ul className="admin-list">
            {activity.map((entry) => (
              <li key={entry.id} className="admin-record-meta">
                <strong>{entry.action}</strong> · {entry.entity_id} · {moment(entry.created_at)}
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </>
  );
}
