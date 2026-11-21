/**
 * Applies db/schema.sql and seeds the team table from the site's existing
 * content, so the dashboard starts with the real people rather than an empty
 * list. Run with: npm run db:install
 */
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { neon } from "@neondatabase/serverless";

import team from "../components/team-data.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const url = (process.env.DATABASE_URL ?? "").trim();

if (url === "") {
  console.error("DATABASE_URL is not set. Add it to website/.env.local first.");
  process.exit(1);
}

const sql = neon(url);

const schema = await readFile(path.join(here, "schema.sql"), "utf8");
const statements = schema
  .split(/;\s*(?:\n|$)/)
  .map((statement) => statement.replace(/^\s*(--[^\n]*\n\s*)*/gm, "").trim())
  .filter((statement) => statement !== "");

for (const statement of statements) {
  await sql.query(statement);
}
console.log(`schema: applied ${statements.length} statements`);

const [{ count }] = await sql.query("select count(*)::int as count from team_members");
if (count === 0) {
  for (const [index, member] of team.entries()) {
    await sql.query(
      "insert into team_members (name, role, focus, image, bio, position, published) values ($1,$2,$3,$4,$5,$6,true)",
      [member.name, member.role, member.focus ?? "", member.image ?? "", member.bio ?? "", index],
    );
  }
  console.log(`seed: inserted ${team.length} team members`);
} else {
  console.log(`seed: team_members already has ${count} rows, left alone`);
}

const [{ news }] = await sql.query("select count(*)::int as news from news_posts");
console.log(`news_posts: ${news} rows`);
console.log("done");
