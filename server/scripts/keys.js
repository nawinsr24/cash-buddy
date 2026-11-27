// Writes fresh local secrets to .dev.vars. The public key is printed for the
// app build; the private key and admin token never are.
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { existsSync, writeFileSync } from 'node:fs';

if (existsSync(process.argv[2] ?? '.dev.vars')) {
  console.error('That file already exists; delete it to make new keys.');
  process.exit(1);
}
const file = process.argv[2] ?? '.dev.vars';
const { publicKey, privateKey } = generateKeyPairSync('ed25519');
const secret = privateKey.export({ type: 'pkcs8', format: 'der' }).toString('base64');
const open = publicKey.export({ type: 'spki', format: 'der' }).subarray(-32).toString('base64');
writeFileSync(file,
  `SIGNING_KEY="${secret}"\nADMIN_TOKEN="${randomBytes(32).toString('hex')}"\nPUBLIC_KEY="${open}"\n`,
  { mode: 0o600 });
console.log(`App build key: --dart-define=ACCESS_KEY=${open}`);
