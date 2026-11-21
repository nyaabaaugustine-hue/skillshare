import { requireAdmin } from "../../lib/admin-auth";
import { db } from "../../lib/db";

export const dynamic = "force-dynamic";

const when = (value) =>
  new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));

export default async function AdminOverviewPage() {
  await requireAdmin();
  const sql = db();

  const [counts] = await sql`
    select
      (select count(*)::int from school_enquiries) as enquiries,
      (select count(*)::int from school_enquiries where status = 'new') as new_enquiries,
      (select count(*)::int from team_members) as team,
      (select count(*)::int from news_posts) as news,
      (select count(*)::int from news_posts where published = true) as published_news,
      (select count(*)::int from learners) as learners,
      (select count(*)::int from learners where stage = 'learning') as learning,
      (select count(*)::int from learners where stage = 'signed_up') as signed_up,
      (select count(*)::int from lms_courses) as courses,
      (select count(*)::int from lms_courses where published = true) as published_courses,
      (select count(*)::int from pwa_apps) as apps,
      (select count(*)::int from pwa_apps where published = true) as published_apps
  `;

  let platform = { students: 0, suspended: 0 };
  try {
    const rows = await sql`
      select
        (select count(*)::int from neon_auth."user") as students,
        (select count(*)::int from app_users where status <> 'active') as suspended
    `;
    platform = rows[0] ?? platform;
  } catch {
    // Neon Auth not enabled on this database yet; the card shows zeroes.
  }

  const recent = await sql`
    select id, school_name, contact_name, email, learner_count, status, created_at
    from school_enquiries
    order by created_at desc
    limit 5
  `;

  return (
    <>
      <header className="admin-head">
        <h1>Overview</h1>
        <p>Everything the public site shows, and everyone who has asked about it.</p>
      </header>

      <section className="admin-stats" aria-label="Summary">
        <article className="admin-stat">
          <span>New enquiries</span>
          <strong>{counts.new_enquiries}</strong>
          <small>{counts.enquiries} total</small>
        </article>
        <article className="admin-stat">
          <span>Team members</span>
          <strong>{counts.team}</strong>
          <small>Shown on the homepage</small>
        </article>
        <article className="admin-stat">
          <span>Published news</span>
          <strong>{counts.published_news}</strong>
          <small>{counts.news} written</small>
        </article>
        <article className="admin-stat">
          <span>Learners</span>
          <strong>{counts.learning}</strong>
          <small>{counts.learners} signed up · {counts.signed_up} waiting</small>
        </article>
        <article className="admin-stat">
          <span>LMS students</span>
          <strong>{platform.students}</strong>
          <small>{platform.suspended} suspended · app accounts</small>
        </article>
        <article className="admin-stat">
          <span>LMS courses</span>
          <strong>{counts.published_courses}</strong>
          <small>{counts.courses} in the catalogue</small>
        </article>
        <article className="admin-stat">
          <span>PWA apps</span>
          <strong>{counts.published_apps}</strong>
          <small>{counts.apps} listed</small>
        </article>
      </section>

      <section className="admin-panel">
        <div className="admin-panel-head">
          <h2>Latest school enquiries</h2>
          <a className="admin-text-link" href="/admin/enquiries">View all</a>
        </div>

        {recent.length === 0 ? (
          <p className="admin-empty">
            No enquiries yet. Submissions from the school form on the homepage land here.
          </p>
        ) : (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th scope="col">School</th>
                  <th scope="col">Contact</th>
                  <th scope="col">Learners</th>
                  <th scope="col">Received</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {recent.map((row) => (
                  <tr key={row.id}>
                    <td>{row.school_name}</td>
                    <td>
                      {row.contact_name}
                      <small>{row.email}</small>
                    </td>
                    <td>{row.learner_count || "—"}</td>
                    <td>{when(row.created_at)}</td>
                    <td>
                      <span className={`admin-pill admin-pill-${row.status}`}>{row.status}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
