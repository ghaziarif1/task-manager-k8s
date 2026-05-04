const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const pool = require("./db");

const app = express();
const port = process.env.PORT || 4000;

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || "*" }));
app.use(express.json());
app.use(morgan("combined"));

// Retry logic pour attendre que PostgreSQL soit prêt
const waitForDB = async (maxRetries = 10, delayMs = 2000) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await pool.query("SELECT 1");
      console.log(`✓ Base de données prête après ${i} tentative(s)`);
      return;
    } catch (error) {
      console.log(`⏳ Attente de la BD... (tentative ${i + 1}/${maxRetries})`);
      if (i < maxRetries - 1) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }
  throw new Error("Base de données non accessible après plusieurs tentatives");
};

const ensureSchema = async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS tasks (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      description TEXT DEFAULT '',
      status VARCHAR(50) NOT NULL DEFAULT 'pending',
      due_date DATE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
};

app.get("/health", (req, res) => {
  res.json({ status: "ok", uptime: process.uptime() });
});

app.get("/api/tasks", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM tasks ORDER BY due_date NULLS LAST, id ASC;");
    res.json(result.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Impossible de récupérer les tâches" });
  }
});

app.post("/api/tasks", async (req, res) => {
  const { title, description = "", status = "pending", due_date } = req.body;
  if (!title || typeof title !== "string") {
    return res.status(400).json({ error: "Le champ title est requis" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO tasks (title, description, status, due_date)
       VALUES ($1, $2, $3, $4)
       RETURNING *;`,
      [title, description, status, due_date || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Impossible de créer la tâche" });
  }
});

app.put("/api/tasks/:id", async (req, res) => {
  const { id } = req.params;
  const { title, description, status, due_date } = req.body;

  try {
    const existing = await pool.query("SELECT * FROM tasks WHERE id = $1", [id]);
    if (!existing.rows.length) {
      return res.status(404).json({ error: "Tâche non trouvée" });
    }

    const updated = await pool.query(
      `UPDATE tasks
       SET title = COALESCE($1, title),
           description = COALESCE($2, description),
           status = COALESCE($3, status),
           due_date = COALESCE($4, due_date),
           updated_at = NOW()
       WHERE id = $5
       RETURNING *;`,
      [title, description, status, due_date, id]
    );
    res.json(updated.rows[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Impossible de mettre à jour la tâche" });
  }
});

app.delete("/api/tasks/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query("DELETE FROM tasks WHERE id = $1 RETURNING *", [id]);
    if (!result.rows.length) {
      return res.status(404).json({ error: "Tâche non trouvée" });
    }
    res.json({ deleted: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Impossible de supprimer la tâche" });
  }
});

// Démarrage du serveur avec attente de la BD
const startServer = async () => {
  try {
    await waitForDB();
    await ensureSchema();
    app.listen(port, () => {
      console.log(`✓ Backend démarré sur http://localhost:${port}`);
    });
  } catch (error) {
    console.error("❌ Erreur d'initialisation du backend:", error.message);
    process.exit(1);
  }
};

startServer();
