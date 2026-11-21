import { isAdmin } from "../../lib/admin-auth";
import AdminNav from "./admin-nav";
import "./admin.css";

export const metadata = {
  title: "SkillBridge admin",
  robots: { index: false, follow: false },
};

export default async function AdminLayout({ children }) {
  const signedIn = await isAdmin();

  if (!signedIn) {
    return (
      <div className="admin-gate">
        <div className="admin-gate-card">
          <span className="admin-eyebrow">SKILLBRIDGE ADMIN</span>
          {children}
        </div>
      </div>
    );
  }

  return (
    <div className="admin-shell">
      <aside className="admin-side">
        <div className="admin-brand">
          <strong>SKILLBRIDGE</strong>
          <small>Admin</small>
        </div>
        <AdminNav />
        <div className="admin-side-foot">
          <a href="/" target="_blank" rel="noreferrer">View site ↗</a>
          <form action="/api/admin/logout" method="post">
            <button type="submit" className="admin-link-button">Sign out</button>
          </form>
        </div>
      </aside>
      <main className="admin-main">{children}</main>
    </div>
  );
}
