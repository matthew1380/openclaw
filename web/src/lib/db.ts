import "server-only";
import { Pool } from "pg";

declare global {
  // eslint-disable-next-line no-var
  var __PG_POOL__: Pool | undefined;
}

function buildPool(): Pool {
  const connectionString = process.env.SUPABASE_DB_URL;
  if (!connectionString) {
    throw new Error(
      "SUPABASE_DB_URL is not set. Copy web/.env.local.example to web/.env.local and fill it in.",
    );
  }
  return new Pool({
    connectionString,
    max: 5,
    idleTimeoutMillis: 30_000,
    ssl: { rejectUnauthorized: false },
  });
}

export const pool: Pool = global.__PG_POOL__ ?? buildPool();
if (process.env.NODE_ENV !== "production") {
  global.__PG_POOL__ = pool;
}

export async function query<T = unknown>(
  text: string,
  params?: unknown[],
): Promise<T[]> {
  const result = await pool.query(text, params as never);
  return result.rows as T[];
}
