import teamFallback from "../components/team-data";
import { tryDb } from "./db";

/**
 * The homepage news block, used until an admin publishes a story.
 */
export const newsFallback = {
  title: "Every young person deserves the chance to create with technology.",
  excerpt:
    "Follow our programmes, community activities and the ideas young people are bringing to life.",
  image:
    "https://res.cloudinary.com/dx1nrew3h/image/upload/v1794785382/child-surfing-internet-tablet-computer_342744-389_e16uvq.avif",
};

/** Published team members, newest configuration first, else the repo content. */
export async function getTeamMembers() {
  const sql = tryDb();
  if (!sql) return teamFallback;
  try {
    const rows = await sql`
      select id, name, role, focus, image, bio
      from team_members
      where published = true
      order by position asc, id asc
    `;
    return rows.length > 0 ? rows : teamFallback;
  } catch {
    return teamFallback;
  }
}

/** Newest published news story, or the placeholder block. */
export async function getFeaturedNews() {
  const sql = tryDb();
  if (!sql) return newsFallback;
  try {
    const rows = await sql`
      select id, title, excerpt, image
      from news_posts
      where published = true order by created_at desc limit 1
    `;
    const post = rows[0];
    if (!post) return newsFallback;
    return {
      title: post.title,
      excerpt: post.excerpt ?? newsFallback.excerpt,
      image: post.image ?? newsFallback.image,
    };
  } catch {
    return newsFallback;
  }
}
