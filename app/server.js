const http = require("http");
const { Client } = require("pg");

const port = process.env.PORT || 8080;

async function checkDb() {
  const c = new Client({
    host: process.env.PGHOST,
    port: Number(process.env.PGPORT || "5432"),
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
    ssl: { rejectUnauthorized: false } 
  });

  await c.connect();
  await c.query("select 1");
  await c.end();
  return true;
}

const server = http.createServer(async (req, res) => {
  if (req.url === "/health") {
    res.writeHead(200);
    res.end("ok\n");
    return;
  }

  if (req.url === "/db") {
    try {
      await checkDb();
      res.writeHead(200);
      res.end("db_ok\n");
    } catch (e) {
      res.writeHead(500);
      res.end("db_error: " + e.message + "\n");
    }
    return;
  }

  res.writeHead(404);
  res.end("not found\n");
});

server.listen(port, () => console.log(`listening on ${port}`));
