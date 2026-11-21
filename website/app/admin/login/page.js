import { redirect } from "next/navigation";

import { demoEnabled, isAdmin } from "../../../lib/admin-auth";

export const metadata = { title: "Admin sign in — SkillBridge" };

export default async function AdminLoginPage({ searchParams }) {
  if (await isAdmin()) redirect("/admin");

  const params = await searchParams;
  const failed = params?.error === "1";

  return (
    <>
      <h1>Sign in</h1>
      <p className="admin-gate-copy">
        Enter the admin password to manage school enquiries, team members and news.
      </p>
      <form action="/api/admin/login" method="post" className="admin-form">
        <label className="admin-field">
          <span>Password</span>
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            autoFocus
            required
          />
        </label>
        {failed ? (
          <p className="admin-alert admin-alert-error" role="alert">
            That password did not match. Try again.
          </p>
        ) : null}
        <button type="submit" className="admin-button admin-button-primary">
          Sign in
        </button>
      </form>

      {demoEnabled() ? (
        <div className="admin-demo">
          <span className="admin-demo-label">DEMO MODE</span>
          <form action="/api/admin/login" method="post">
            <input type="hidden" name="intent" value="demo" />
            <button type="submit" className="admin-button admin-button-demo">
              Enter the demo dashboard →
            </button>
          </form>
          <p className="admin-gate-note">
            No password needed while ADMIN_DEMO=1 is set. Remove it before the site
            goes live.
          </p>
        </div>
      ) : null}
    </>
  );
}
