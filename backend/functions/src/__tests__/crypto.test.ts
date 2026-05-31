// =============================================================================
// Crypto helpers tests — PBKDF2 + HMAC sin dependencias de Firebase
// =============================================================================
// Ejecutar: npx ts-node --transpile-only src/__tests__/crypto.test.ts
//
// Se replican los helpers para testearlos sin tener que inicializar Admin SDK.
// Si se cambian las funciones reales (auth.ts, qr.ts), actualizar también acá.
// =============================================================================
import * as crypto from "crypto";
import * as assert from "assert";

// ----- Helpers replicados de auth.ts ----------------------------------------
const PBKDF2_ALGO = "sha512";
const PBKDF2_ITER = 210_000;
const PBKDF2_KEYLEN = 32;
const PBKDF2_SALTLEN = 16;

function pbkdf2Hash(password: string, saltB64: string): string {
  const salt = Buffer.from(saltB64, "base64");
  const derived = crypto.pbkdf2Sync(
    password, salt, PBKDF2_ITER, PBKDF2_KEYLEN, PBKDF2_ALGO,
  );
  return derived.toString("base64");
}

function newSalt(): string {
  return crypto.randomBytes(PBKDF2_SALTLEN).toString("base64");
}

function encodePhc(salt: string, hash: string): string {
  return `pbkdf2$${PBKDF2_ALGO}$${PBKDF2_ITER}$${salt}$${hash}`;
}

function decodePhc(s: string): { salt: string; hash: string; iter: number } | null {
  const parts = s.split("$");
  if (parts.length !== 5 || parts[0] !== "pbkdf2") return null;
  return { salt: parts[3], hash: parts[4], iter: parseInt(parts[2], 10) };
}

function safeEqual(a: string, b: string): boolean {
  const aB = Buffer.from(a);
  const bB = Buffer.from(b);
  if (aB.length !== bB.length) return false;
  return crypto.timingSafeEqual(aB, bB);
}

// ----- Helpers replicados de qr.ts ------------------------------------------
function canonicalize(obj: Record<string, unknown>): string {
  const keys = Object.keys(obj).filter((k) => k !== "sig").sort();
  const ordered: Record<string, unknown> = {};
  for (const k of keys) {
    if (obj[k] !== undefined && obj[k] !== null) ordered[k] = obj[k];
  }
  return JSON.stringify(ordered);
}

function hmacSign(payload: Record<string, unknown>, secret: string): string {
  const data = canonicalize(payload);
  return crypto.createHmac("sha256", Buffer.from(secret, "base64"))
    .update(data).digest("base64url");
}

// ============================================================================
// Tests
// ============================================================================
let passed = 0;
let failed = 0;

function test(name: string, fn: () => void) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.error(`  ✗ ${name}\n    ${(e as Error).message}`);
  }
}

console.log("PBKDF2 password hashing");

test("hash es determinístico para misma password+salt", () => {
  const salt = newSalt();
  assert.strictEqual(pbkdf2Hash("pwd123", salt), pbkdf2Hash("pwd123", salt));
});

test("passwords distintas producen hashes distintos", () => {
  const salt = newSalt();
  assert.notStrictEqual(pbkdf2Hash("aaa", salt), pbkdf2Hash("bbb", salt));
});

test("misma password con salts distintos produce hashes distintos", () => {
  assert.notStrictEqual(pbkdf2Hash("pwd", newSalt()), pbkdf2Hash("pwd", newSalt()));
});

test("encodePhc / decodePhc round-trip", () => {
  const salt = newSalt();
  const hash = pbkdf2Hash("pwd", salt);
  const phc = encodePhc(salt, hash);
  const decoded = decodePhc(phc);
  assert.ok(decoded);
  assert.strictEqual(decoded!.salt, salt);
  assert.strictEqual(decoded!.hash, hash);
  assert.strictEqual(decoded!.iter, PBKDF2_ITER);
});

test("decodePhc rechaza formato malo", () => {
  assert.strictEqual(decodePhc("not-pbkdf2$x$y$z"), null);
  assert.strictEqual(decodePhc(""), null);
  assert.strictEqual(decodePhc("pbkdf2$only$two"), null);
});

test("safeEqual: iguales", () => {
  assert.strictEqual(safeEqual("hello", "hello"), true);
});

test("safeEqual: distintos", () => {
  assert.strictEqual(safeEqual("hello", "world"), false);
});

test("safeEqual: longitudes distintas no crashea", () => {
  assert.strictEqual(safeEqual("a", "abc"), false);
});

test("newSalt es base64 de >= 16 bytes (>=22 chars b64)", () => {
  const s = newSalt();
  assert.ok(s.length >= 22, `salt length was ${s.length}`);
});

console.log("\nHMAC QR signing");

test("hmacSign es determinístico para mismo payload+secret", () => {
  const payload = { c: "Sky", h: 1, k: "abc", exp: 1700000000000 };
  const secret = Buffer.from(crypto.randomBytes(32)).toString("base64");
  assert.strictEqual(hmacSign(payload, secret), hmacSign(payload, secret));
});

test("hmacSign distinto para secrets distintos", () => {
  const payload = { c: "Sky", h: 1 };
  const s1 = Buffer.from(crypto.randomBytes(32)).toString("base64");
  const s2 = Buffer.from(crypto.randomBytes(32)).toString("base64");
  assert.notStrictEqual(hmacSign(payload, s1), hmacSign(payload, s2));
});

test("canonicalize ignora la firma sig al recalcular", () => {
  const a = { c: "Sky", h: 1 };
  const b = { c: "Sky", h: 1, sig: "fake_signature" };
  assert.strictEqual(canonicalize(a), canonicalize(b));
});

test("canonicalize ordena keys (orden de inserción no importa)", () => {
  const a = { c: "Sky", h: 1, exp: 100 };
  const b = { exp: 100, h: 1, c: "Sky" };
  assert.strictEqual(canonicalize(a), canonicalize(b));
});

test("canonicalize ignora undefined/null", () => {
  const a = { c: "Sky", h: 1 };
  const b = { c: "Sky", h: 1, vci: undefined, u: null };
  assert.strictEqual(canonicalize(a), canonicalize(b));
});

test("tamper en payload produce firma distinta (no se valida)", () => {
  const secret = Buffer.from(crypto.randomBytes(32)).toString("base64");
  const original = { c: "Sky", h: 1, k: "abc", exp: 1700000000000 };
  const tampered = { c: "Sky", h: 999, k: "abc", exp: 1700000000000 };
  assert.notStrictEqual(hmacSign(original, secret), hmacSign(tampered, secret));
});

console.log(`\nResumen: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
