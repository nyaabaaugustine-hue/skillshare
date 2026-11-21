import { requireAdmin } from "../../../lib/admin-auth";
import { db } from "../../../lib/db";

export const dynamic = "force-dynamic";

function MemberFields({ member }) {
  return (
    <div className="admin-grid">
      <label className="admin-field">
        <span>Name</span>
        <input name="name" defaultValue={member?.name ?? ""} required maxLength={120} />
      </label>
      <label className="admin-field">
        <span>Role</span>
        <input name="role" defaultValue={member?.role ?? ""} required maxLength={160} />
      </label>
      <label className="admin-field">
        <span>Focus</span>
        <input name="focus" defaultValue={member?.focus ?? ""} maxLength={120} />
      </label>
      <label className="admin-field">
        <span>Order</span>
        <input
          name="position"
          type="number"
          defaultValue={member?.position ?? 0}
          min={0}
          max={999}
        />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Photo URL</span>
        <input name="image" defaultValue={member?.image ?? ""} maxLength={1200} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Short biography</span>
        <textarea name="bio" rows={3} defaultValue={member?.bio ?? ""} maxLength={1200} />
      </label>
      <label className="admin-check">
        <input type="checkbox" name="published" defaultChecked={member?.published ?? true} />
        <span>Show on the website</span>
      </label>
    </div>
  );
}

export default async function AdminTeamPage({ searchParams }) {
  await requireAdmin();
  const params = await searchParams;

  const members = await db()`
    select id, name, role, focus, image, bio, position, published
    from team_members
    order by position asc, id asc
  `;

  return (
    <>
      <header className="admin-head">
        <h1>Team</h1>
        <p>These people appear on the homepage and on the team page.</p>
      </header>

      {params?.saved ? (
        <p className="admin-alert admin-alert-ok" role="status">Saved.</p>
      ) : null}
      {params?.error ? (
        <p className="admin-alert admin-alert-error" role="alert">
          That did not save. Name and role are required.
        </p>
      ) : null}

      <section className="admin-panel">
        <h2>Add a team member</h2>
        <form action="/api/admin/team" method="post" className="admin-form">
          <input type="hidden" name="intent" value="create" />
          <MemberFields />
          <button type="submit" className="admin-button admin-button-primary">
            Add member
          </button>
        </form>
      </section>

      <section className="admin-panel">
        <h2>Current team ({members.length})</h2>

        {members.length === 0 ? (
          <p className="admin-empty">No team members yet.</p>
        ) : (
          <ul className="admin-list">
            {members.map((member) => (
              <li key={member.id} className="admin-record">
                <div className="admin-record-head">
                  <div className="admin-person">
                    {member.image ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={member.image} alt="" width={44} height={44} />
                    ) : null}
                    <div>
                      <h3>{member.name}</h3>
                      <p className="admin-record-meta">{member.role}</p>
                    </div>
                  </div>
                  <span className={`admin-pill admin-pill-${member.published ? "new" : "closed"}`}>
                    {member.published ? "published" : "hidden"}
                  </span>
                </div>

                <details className="admin-details">
                  <summary>Edit details</summary>
                  <form action="/api/admin/team" method="post" className="admin-form">
                    <input type="hidden" name="intent" value="update" />
                    <input type="hidden" name="id" value={member.id} />
                    <MemberFields member={member} />
                    <button type="submit" className="admin-button admin-button-primary">
                      Save changes
                    </button>
                  </form>
                </details>

                <form action="/api/admin/team" method="post" className="admin-actions">
                  <input type="hidden" name="intent" value="delete" />
                  <input type="hidden" name="id" value={member.id} />
                  <button type="submit" className="admin-button admin-button-danger">
                    Remove
                  </button>
                </form>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
