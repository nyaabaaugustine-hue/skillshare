import { requireAdmin } from "../../../lib/admin-auth";
import { db } from "../../../lib/db";

export const dynamic = "force-dynamic";

const when = (value) =>
  new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));

const STATUSES = ["new", "contacted", "closed"];

export default async function AdminEnquiriesPage({ searchParams }) {
  await requireAdmin();
  const params = await searchParams;

  const rows = await db()`
    select id, school_name, school_location, contact_name, email, phone,
           learner_count, programme_interest, message, status, created_at
    from school_enquiries
    order by created_at desc
  `;

  return (
    <>
      <header className="admin-head">
        <h1>School enquiries</h1>
        <p>{rows.length} submitted through the school registration form.</p>
      </header>

      {params?.saved ? (
        <p className="admin-alert admin-alert-ok" role="status">Saved.</p>
      ) : null}
      {params?.error ? (
        <p className="admin-alert admin-alert-error" role="alert">
          That change did not save. Check the details and try again.
        </p>
      ) : null}

      {rows.length === 0 ? (
        <p className="admin-empty">Nothing here yet.</p>
      ) : (
        <ul className="admin-list">
          {rows.map((row) => (
            <li key={row.id} className="admin-record">
              <div className="admin-record-head">
                <div>
                  <h2>{row.school_name}</h2>
                  <p className="admin-record-meta">
                    {row.school_location} · {row.contact_name} ·{" "}
                    <a href={`mailto:${row.email}`}>{row.email}</a>
                    {row.phone ? <> · {row.phone}</> : null}
                  </p>
                </div>
                <span className={`admin-pill admin-pill-${row.status}`}>{row.status}</span>
              </div>

              <p className="admin-record-meta">
                {when(row.created_at)} · {row.learner_count || "learner count not given"} ·{" "}
                {row.programme_interest || "programme not specified"}
              </p>

              {row.message ? <p className="admin-record-body">{row.message}</p> : null}

              <div className="admin-actions">
                {STATUSES.filter((status) => status !== row.status).map((status) => (
                  <form action="/api/admin/enquiries" method="post" key={status}>
                    <input type="hidden" name="id" value={row.id} />
                    <input type="hidden" name="status" value={status} />
                    <button type="submit" className="admin-button admin-button-quiet">
                      Mark {status}
                    </button>
                  </form>
                ))}
                <form action="/api/admin/enquiries" method="post">
                  <input type="hidden" name="id" value={row.id} />
                  <input type="hidden" name="intent" value="delete" />
                  <button type="submit" className="admin-button admin-button-danger">
                    Delete
                  </button>
                </form>
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
