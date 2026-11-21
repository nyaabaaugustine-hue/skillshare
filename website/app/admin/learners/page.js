import { requireAdmin } from "../../../lib/admin-auth";
import { db } from "../../../lib/db";

export const dynamic = "force-dynamic";

const STAGES = [
  { value: "signed_up", label: "Signed up" },
  { value: "learning", label: "Learning" },
  { value: "paused", label: "Paused" },
  { value: "completed", label: "Completed" },
];

const label = (value) => STAGES.find((stage) => stage.value === value)?.label ?? value;

function LearnerFields({ learner }) {
  return (
    <div className="admin-grid">
      <label className="admin-field">
        <span>Full name</span>
        <input name="full_name" defaultValue={learner?.full_name ?? ""} required maxLength={160} />
      </label>
      <label className="admin-field">
        <span>Email</span>
        <input name="email" type="email" defaultValue={learner?.email ?? ""} required maxLength={200} />
      </label>
      <label className="admin-field">
        <span>Phone</span>
        <input name="phone" defaultValue={learner?.phone ?? ""} maxLength={60} />
      </label>
      <label className="admin-field">
        <span>School or community</span>
        <input name="school" defaultValue={learner?.school ?? ""} maxLength={160} />
      </label>
      <label className="admin-field">
        <span>Course</span>
        <input name="programme" defaultValue={learner?.programme ?? "Python for Beginners"} maxLength={120} />
      </label>
      <label className="admin-field">
        <span>Stage</span>
        <select name="stage" defaultValue={learner?.stage ?? "signed_up"}>
          {STAGES.map((stage) => (
            <option key={stage.value} value={stage.value}>{stage.label}</option>
          ))}
        </select>
      </label>
      <label className="admin-field">
        <span>Progress (%)</span>
        <input
          name="progress"
          type="number"
          min={0}
          max={100}
          defaultValue={learner?.progress ?? 0}
        />
      </label>
      <label className="admin-field admin-field-wide">
        <span>Notes</span>
        <textarea name="notes" rows={3} defaultValue={learner?.notes ?? ""} maxLength={2000} />
      </label>
    </div>
  );
}

export default async function AdminLearnersPage({ searchParams }) {
  await requireAdmin();
  const params = await searchParams;

  const learners = await db()`
    select id, full_name, email, phone, school, programme, stage, progress, notes,
           created_at, updated_at
    from learners
    order by
      case stage
        when 'learning' then 0
        when 'signed_up' then 1
        when 'paused' then 2
        else 3
      end,
      created_at desc
  `;

  const count = (stage) => learners.filter((learner) => learner.stage === stage).length;

  return (
    <>
      <header className="admin-head">
        <h1>Learners</h1>
        <p>Who signed up, who is learning, and how far each student has got.</p>
      </header>

      {params?.saved ? (
        <p className="admin-alert admin-alert-ok" role="status">Saved.</p>
      ) : null}
      {params?.error ? (
        <p className="admin-alert admin-alert-error" role="alert">
          That did not save. A name and a valid email are required.
        </p>
      ) : null}

      <section className="admin-stats" aria-label="Learner stages">
        <article className="admin-stat">
          <span>All learners</span>
          <strong>{learners.length}</strong>
          <small>{count("signed_up")} waiting to start</small>
        </article>
        <article className="admin-stat">
          <span>Learning now</span>
          <strong>{count("learning")}</strong>
          <small>Active students</small>
        </article>
        <article className="admin-stat">
          <span>Completed</span>
          <strong>{count("completed")}</strong>
          <small>{count("paused")} paused</small>
        </article>
      </section>

      <section className="admin-panel">
        <h2>Add a learner</h2>
        <form action="/api/admin/learners" method="post" className="admin-form">
          <input type="hidden" name="intent" value="create" />
          <LearnerFields />
          <button type="submit" className="admin-button admin-button-primary">
            Add learner
          </button>
        </form>
      </section>

      <section className="admin-panel">
        <h2>Learners ({learners.length})</h2>

        {learners.length === 0 ? (
          <p className="admin-empty">
            Nobody has signed up yet. Enrolments from the Python course on the homepage
            appear here automatically.
          </p>
        ) : (
          <ul className="admin-list">
            {learners.map((learner) => (
              <li key={learner.id} className="admin-record">
                <div className="admin-record-head">
                  <div>
                    <h3>{learner.full_name}</h3>
                    <p className="admin-record-meta">
                      <a href={`mailto:${learner.email}`}>{learner.email}</a>
                      {learner.school ? <> · {learner.school}</> : null}
                      {learner.phone ? <> · {learner.phone}</> : null}
                    </p>
                  </div>
                  <span className={`admin-pill admin-pill-${learner.stage}`}>
                    {label(learner.stage)}
                  </span>
                </div>

                <p className="admin-record-meta">
                  {learner.programme} · {learner.progress}% through
                </p>
                <div className="admin-progress" aria-hidden="true">
                  <span style={{ width: `${Math.min(100, Math.max(0, learner.progress))}%` }} />
                </div>

                {learner.notes ? <p className="admin-record-body">{learner.notes}</p> : null}

                <div className="admin-actions">
                  {STAGES.filter((stage) => stage.value !== learner.stage).map((stage) => (
                    <form action="/api/admin/learners" method="post" key={stage.value}>
                      <input type="hidden" name="id" value={learner.id} />
                      <input type="hidden" name="intent" value="stage" />
                      <input type="hidden" name="stage" value={stage.value} />
                      <button type="submit" className="admin-button admin-button-quiet">
                        Move to {stage.label.toLowerCase()}
                      </button>
                    </form>
                  ))}
                </div>

                <details className="admin-details">
                  <summary>Edit learner and progress</summary>
                  <form action="/api/admin/learners" method="post" className="admin-form">
                    <input type="hidden" name="intent" value="update" />
                    <input type="hidden" name="id" value={learner.id} />
                    <LearnerFields learner={learner} />
                    <button type="submit" className="admin-button admin-button-primary">
                      Save changes
                    </button>
                  </form>
                </details>

                <form action="/api/admin/learners" method="post" className="admin-actions">
                  <input type="hidden" name="intent" value="delete" />
                  <input type="hidden" name="id" value={learner.id} />
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
