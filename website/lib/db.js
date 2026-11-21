import { neon } from "@neondatabase/serverless";

/**
 * One Neon HTTP client per process. The HTTP driver needs no connection pool,
 * so it behaves the same in `next dev` and in a serverless deployment.
 */
let client;

export function db() {
  const url = (process.env.DATABASE_URL ?? "").trim();
  if (url === "") {
    throw new Error("DATABASE_URL is not set. See website/.env.local.");
  }
  client ??= neon(url);
  return client;
}

/**
 * Same client, but null instead of throwing. Public pages use this so a missing
 * or unreachable database degrades to the content already in the repository
 * rather than a 500 on the homepage.
 */
export function tryDb() {
  try {
    return db();
  } catch {
    return null;
  }
}
