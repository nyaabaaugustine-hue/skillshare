import { requireAdmin } from "../../../lib/admin-auth";
import { db } from "../../../lib/db";

export const dynamic = "force-dynamic";

function AppFields({ app }) {
  return (
    <div className="admin-grid">
      <label className="admin-field">
        <span>App name</span>
        <input name="name" defaultValue={app?.name ?? ""} required maxLength={160} />
      </label>
      <label className="admin-field">
        <span>Category</span>
        <input name="category" defaultValue={app?.category ?? ""} maxLength={80} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Description</span>
        <textarea name="description" rows={3} defaultValue={app?.description ?? ""} maxLength={600} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>App URL</span>
        <input name="url" defaultValue={app?.url ?? ""} maxLength={1200} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Icon URL</span>
        <input name="icon" defaultValue={app?.icon ?? ""} maxLength={1200} />
      </label>
      <label className="admin-field">
        <span>Order</span>
        <input
          name="position"
          type="number"
          defaultValue={app?.position ?? 0}
          min={0}
          max={999}
        />
      </label>
      <label className="admin-check">
        <input type="checkbox" name="published" defaultChecked={app?.published ?? true} />
        <span>Show in the app list</span>
      </label>
    </div>
  );
}

export default async function AdminAppsPage({ searchParams }) {
  await requireAdmin();
  const params = await searchParams;

  const apps = await db()`
    select id, name, category, description, url, icon, position, published
    from pwa_apps
    order by position asc, id asc
  `;

  return (
    <>
      <header className="admin-head">
        <h1>PWA apps</h1>
        <p>The installable apps listed for learners and partner schools.</p>
      </header>

      {params?.saved ? (
        <p className="admin-alert admin-alert-ok" role="status">Saved.</p>
      ) : null}
      {params?.error ? (
        <p className="admin-alert admin-alert-error" role="alert">
          That did not save. An app name is required.
        </p>
      ) : null}

      <section className="admin-panel">
        <h2>Add an app</h2>
        <form action="/api/admin/apps" method="post" className="admin-form">
          <input type="hidden" name="intent" value="create" />
          <AppFields />
          <button type="submit" className="admin-button admin-button-primary">
            Add app
          </button>
        </form>
      </section>

      <section className="admin-panel">
        <h2>Apps ({apps.length})</h2>

        {apps.length === 0 ? (
          <p className="admin-empty">No apps yet.</p>
        ) : (
          <ul className="admin-list">
            {apps.map((app) => (
              <li key={app.id} className="admin-record">
                <div className="admin-record-head">
                  <div className="admin-person">
                    {app.icon ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={app.icon} alt="" width={44} height={44} />
                    ) : null}
                    <div>
                      <h3>{app.name}</h3>
                      <p className="admin-record-meta">{app.category || "uncategorised"}</p>
                    </div>
                  </div>
                  <span className={`admin-pill admin-pill-${app.published ? "new" : "closed"}`}>
                    {app.published ? "published" : "hidden"}
                  </span>
                </div>

                {app.description ? (
                  <p className="admin-record-body">{app.description}</p>
                ) : null}
                {app.url ? (
                  <p className="admin-record-meta">
                    <a href={app.url} target="_blank" rel="noreferrer">
                      {app.url}
                    </a>
                  </p>
                ) : null}

                <details className="admin-details">
                  <summary>Edit app</summary>
                  <form action="/api/admin/apps" method="post" className="admin-form">
                    <input type="hidden" name="intent" value="update" />
                    <input type="hidden" name="id" value={app.id} />
                    <AppFields app={app} />
                    <button type="submit" className="admin-button admin-button-primary">
                      Save changes
                    </button>
                  </form>
                </details>

                <div className="admin-actions">
                  <form action="/api/admin/apps" method="post">
                    <input type="hidden" name="id" value={app.id} />
                    <input
                      type="hidden"
                      name="intent"
                      value={app.published ? "unpublish" : "publish"}
                    />
                    <button type="submit" className="admin-button admin-button-quiet">
                      {app.published ? "Hide" : "Publish"}
                    </button>
                  </form>
                  <form action="/api/admin/apps" method="post">
                    <input type="hidden" name="id" value={app.id} />
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
      </section>
    </>
  );
}
