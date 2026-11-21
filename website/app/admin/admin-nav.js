"use client";

import { usePathname } from "next/navigation";

const links = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/enquiries", label: "School enquiries" },
  { href: "/admin/learners", label: "Learners" },
  { href: "/admin/students", label: "LMS students" },
  { href: "/admin/team", label: "Team" },
  { href: "/admin/news", label: "News" },
  { href: "/admin/lms", label: "LMS courses" },
  { href: "/admin/apps", label: "PWA apps" },
];

export default function AdminNav() {
  const pathname = usePathname() ?? "/admin";

  return (
    <nav className="admin-nav" aria-label="Admin sections">
      {links.map((link) => {
        const active =
          link.href === "/admin" ? pathname === "/admin" : pathname.startsWith(link.href);
        return (
          <a
            key={link.href}
            href={link.href}
            className={active ? "is-active" : undefined}
            aria-current={active ? "page" : undefined}
          >
            {link.label}
          </a>
        );
      })}
    </nav>
  );
}
