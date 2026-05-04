const { Pool } = require("pg");

const connectionString =
  process.env.DATABASE_URL ||
  `postgresql://${process.env.POSTGRES_USER || "postgres"}:${process.env.POSTGRES_PASSWORD || "password"}@${process.env.POSTGRES_HOST || "postgres-service"}:${process.env.POSTGRES_PORT || 5432}/${process.env.POSTGRES_DB || "tasks"}`;

const pool = new Pool({
  connectionString,
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
});

module.exports = pool;
