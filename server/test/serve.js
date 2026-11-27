// Runs the server on this computer with a memory database and two signed-in
// users, then runs the command given, with their sessions in the environment.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';

import { call, session } from './harness.js';

const sessions = [
  await session('1', 'in_phone0001'), await session('2', 'in_phone0002'),
].map((s) => Buffer.from(s, 'base64').toString());
// Compact JSON has no spaces, so a space can separate them.

const server = createServer(async (req, res) => {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const reply = await call(req.url, {
    method: req.method,
    headers: req.headers,
    body: chunks.length ? Buffer.concat(chunks).toString() : undefined,
  });
  res.writeHead(reply.status, { 'content-type': 'application/json' });
  res.end(await reply.text());
});
server.listen(0, () => {
  const child = spawn(process.argv[2], process.argv.slice(3), {
    stdio: 'inherit',
    env: {
      ...process.env,
      GROUP_URL: `http://localhost:${server.address().port}`,
      GROUP_SESSIONS: sessions.join(' '),
    },
  });
  child.on('exit', (code) => { server.close(); process.exit(code ?? 1); });
});
