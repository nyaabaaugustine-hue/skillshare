import { requireAdmin } from "../../../lib/admin-auth";
import { db } from "../../../lib/db";

export const dynamic = "force-dynamic";

function NewsFields({ post }) {
  return (
    <div className="admin-grid">
      <label className="admin-field admin-field-wide">
        <span>Title</span>
        <input name="title" defaultValue={post?.title ?? ""} required maxLength={180} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Image URL</span>
        <input name="image" defaultValue={post?.image ?? ""} maxLength={1200} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Summary</span>
        <textarea name="excerpt" rows={2} defaultValue={post?.excerpt ?? ""} maxLength={400} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Full story</span>
        <textarea name="body" rows={6} defaultValue={post?.body ?? ""} maxLength={6000} />
      </label>
      <label className="admin-check">
        <input type="checkbox" name="published" defaultChecked={post?.published ?? false} />
        <span>Publish on the website</span>
      </label>
    </div>
  );
}

export default async function AdminNewsPage({ searchParams }) {
  await requireAdmin();
  const params = await searchParams;

  const posts = await db()`
    select id, title, excerpt, image, body, published, created_at
    from news_posts
    order by created_at desc
  `;

  return (
    <>
      <header className="admin-head">
        <h1>News</h1>
        <p>The newest published story fills the news block on the homepage.</p>
      </header>

      {params?.saved ? (
        <p className="admin-alert admin-alert-ok" role="status">Saved.</p>
      ) : null}
      {params?.error ? (
        <p className="admin-alert admin-alert-error" role="alert">
          That did not save. A title is required.
        </p>
      ) : null}

      <section className="admin-panel">
        <h2>Write a story</h2>
        <form action="/api/admin/news" method="post" className="admin-form">
          <input type="hidden" name="intent" value="create" />
          <NewsFields />
          <button type="submit" className="admin-button admin-button-primary">
            Save story
          </button>
        </form>
      </section>

      <section className="admin-panel">
        <h2>Stories ({posts.length})</h2>

        {posts.length === 0 ? (
          <p className="admin-empty">No stories yet.</p>
        ) : (
          <ul className="admin-list">
            {posts.map((post) => (
              <li key={post.id} className="admin-record">
                <div className="admin-record-head">
                  <div>
                    <h3>{post.title}</h3>
                    <p className="admin-record-meta">
                      {new Intl.DateTimeFormat("en-GB", {
                        day: "2-digit",
                        month: "short",
                        year: "numeric",
                      }).format(new Date(post.created_at))}
                    </p>
                  </div>
                  <span className={`admin-pill admin-pill-${post.published ? "new" : "closed"}`}>
                    {post.published ? "published" : "draft"}
                  </span>
                </div>

                {post.excerpt ? <p className="admin-record-body">{post.excerpt}</p> : null}

                <details className="admin-details">
                  <summary>Edit story</summary>
                  <form action="/api/admin/news" method="post" className="admin-form">
                    <input type="hidden" name="intent" value="update" />
                    <input type="hidden" name="id" value={post.id} />
                    <NewsFields post={post} />
                    <button type="submit" className="admin-button admin-button-primary">
                      Save changes
                    </button>
                  </form>
                </details>

                <div className="admin-actions">
                  <form action="/api/admin/news" method="post">
                    <input type="hidden" name="id" value={post.id} />
                    <input
                      type="hidden"
                      name="intent"
                      value={post.published ? "unpublish" : "publish"}
                    />
                    <button type="submit" className="admin-button admin-button-quiet">
                      {post.published ? "Unpublish" : "Publish"}
                    </button>
                  </form>
                  <form action="/api/admin/news" method="post">
                    <input type="hidden" name="id" value={post.id} />
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
