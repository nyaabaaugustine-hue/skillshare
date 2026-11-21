import { createHmac, timingSafeEqual } from "node:crypto";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

/**
 * Admin auth is deliberately small: one password from the environment, and a
 * signed, expiring cookie. There are no user accounts to manage, and nothing
 * sensitive lives behind the login except the organisation's own content.
 */
export const ADMIN_COOKIE = "sb_admin_session";
export const ADMIN_SESSION_MAX_AGE = 60 * 60 * 8; // 8 hours

function secret() {
  const value = process.env.ADMIN_SESSION_SECRET;
  if (!value) throw new Error("ADMIN_SESSION_SECRET is not set. See website/.env.local.");
  return value;
}

function sign(payload) {
  return createHmac("sha256", secret()).update(payload).digest("base64url");
}

export function createSessionToken(now = Date.now()) {
  const payload = Buffer.from(
    JSON.stringify({ exp: now + ADMIN_SESSION_MAX_AGE * 1000 }),
  ).toString("base64url");
  return `${payload}.${sign(payload)}`;
}

export function verifySessionToken(token) {
  if (typeof token !== "string" || !token.includes(".")) return false;
  const [payload, mac] = token.split(".");
  const expected = sign(payload);
  const given = Buffer.from(mac);
  const wanted = Buffer.from(expected);
  if (given.length !== wanted.length || !timingSafeEqual(given, wanted)) return false;
  try {
    const { exp } = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    return typeof exp === "number" && exp > Date.now();
  } catch {
    return false;
  }
}

export function passwordMatches(input) {
  const expected = process.env.ADMIN_PASSWORD;
  if (!expected || typeof input !== "string" || input === "") return false;
  const given = Buffer.from(input);
  const wanted = Buffer.from(expected);
  if (given.length !== wanted.length) return false;
  return timingSafeEqual(given, wanted);
}

/**
 * One-click demo entry. Set ADMIN_DEMO=1 to show the demo button, and remove
 * that line (or set it to 0) before the site goes live — it skips the
 * password entirely.
 */
export function demoEnabled() {
  return process.env.ADMIN_DEMO === "1";
}

export async function isAdmin() {
  const jar = await cookies();
  return verifySessionToken(jar.get(ADMIN_COOKIE)?.value);
}

/** Server components and page handlers: bounce signed-out visitors to login. */
export async function requireAdmin() {
  if (!(await isAdmin())) redirect("/admin/login");
}

/** Route handlers: return a 401 the fetch caller can act on. */
export async function assertAdmin() {
  if (await isAdmin()) return null;
  return new Response("Unauthorized", { status: 401 });
}
