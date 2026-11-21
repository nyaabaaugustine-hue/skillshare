import { requireAdmin } from "../../../lib/admin-auth";
import { db } from "../../../lib/db";

export const dynamic = "force-dynamic";

function CourseFields({ course }) {
  return (
    <div className="admin-grid">
      <label className="admin-field admin-field-wide">
        <span>Course title</span>
        <input name="title" defaultValue={course?.title ?? ""} required maxLength={180} />
      </label>
      <label className="admin-field">
        <span>Level or age band</span>
        <input name="level" defaultValue={course?.level ?? ""} maxLength={80} />
      </label>
      <label className="admin-field">
        <span>Duration</span>
        <input name="duration" defaultValue={course?.duration ?? ""} maxLength={80} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Summary</span>
        <textarea name="summary" rows={3} defaultValue={course?.summary ?? ""} maxLength={600} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Topics (comma separated)</span>
        <input name="topics" defaultValue={course?.topics ?? ""} maxLength={600} />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Course link</span>
        <input name="link" defaultValue={course?.link ?? ""} maxLength={1200} />
      </label>
      <label className="admin-field">
        <span>Order</span>
        <input
          name="position"
          type="number"
          defaultValue={course?.position ?? 0}
          min={0}
          max={999}
        />
      </label>
      <label className="admin-check">
        <input type="checkbox" name="published" defaultChecked={course?.published ?? true} />
        <span>Show in the LMS</span>
      </label>
    </div>
  );
}

export default async function AdminLmsPage({ searchParams }) {
  await requireAdmin();
  const params = await searchParams;

  const courses = await db()`
    select id, title, level, summary, topics, duration, link, position, published
    from lms_courses
    order by position asc, id asc
  `;

  return (
    <>
      <header className="admin-head">
        <h1>LMS courses</h1>
        <p>The course catalogue learners see in the learning management system.</p>
      </header>

      {params?.saved ? (
        <p className="admin-alert admin-alert-ok" role="status">Saved.</p>
      ) : null}
      {params?.error ? (
        <p className="admin-alert admin-alert-error" role="alert">
          That did not save. A course title is required.
        </p>
      ) : null}

      <section className="admin-panel">
        <h2>Add a course</h2>
        <form action="/api/admin/lms" method="post" className="admin-form">
          <input type="hidden" name="intent" value="create" />
          <CourseFields />
          <button type="submit" className="admin-button admin-button-primary">
            Add course
          </button>
        </form>
      </section>

      <section className="admin-panel">
        <h2>Courses ({courses.length})</h2>

        {courses.length === 0 ? (
          <p className="admin-empty">No courses yet.</p>
        ) : (
          <ul className="admin-list">
            {courses.map((course) => (
              <li key={course.id} className="admin-record">
                <div className="admin-record-head">
                  <div>
                    <h3>{course.title}</h3>
                    <p className="admin-record-meta">
                      {[course.level, course.duration].filter(Boolean).join(" · ") ||
                        "no level set"}
                    </p>
                  </div>
                  <span className={`admin-pill admin-pill-${course.published ? "new" : "closed"}`}>
                    {course.published ? "published" : "hidden"}
                  </span>
                </div>

                {course.summary ? (
                  <p className="admin-record-body">{course.summary}</p>
                ) : null}

                <details className="admin-details">
                  <summary>Edit course</summary>
                  <form action="/api/admin/lms" method="post" className="admin-form">
                    <input type="hidden" name="intent" value="update" />
                    <input type="hidden" name="id" value={course.id} />
                    <CourseFields course={course} />
                    <button type="submit" className="admin-button admin-button-primary">
                      Save changes
                    </button>
                  </form>
                </details>

                <div className="admin-actions">
                  <form action="/api/admin/lms" method="post">
                    <input type="hidden" name="id" value={course.id} />
                    <input
                      type="hidden"
                      name="intent"
                      value={course.published ? "unpublish" : "publish"}
                    />
                    <button type="submit" className="admin-button admin-button-quiet">
                      {course.published ? "Hide" : "Publish"}
                    </button>
                  </form>
                  <form action="/api/admin/lms" method="post">
                    <input type="hidden" name="id" value={course.id} />
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
