// QA harness para loginPropietario contra el emulador Firebase.
// Ejecutar con: firebase emulators:exec "node functions/qa_login.js"
const admin = require("firebase-admin");
const { _pbkdf2 } = require("./lib/auth.js");

admin.initializeApp({ projectId: "demo-fortguards" });
const db = admin.firestore();
const PROJECT = "demo-fortguards";

async function call(fn, data) {
  const res = await fetch(
    `http://127.0.0.1:5001/${PROJECT}/us-central1/${fn}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data }),
    },
  );
  return { status: res.status, body: await res.json() };
}

(async () => {
  let pass = 0,
    fail = 0;
  const check = (name, cond) => {
    if (cond) {
      pass++;
      console.log("  PASS  " + name);
    } else {
      fail++;
      console.log("  FAIL  " + name);
    }
  };

  // Seed: condominio + casa con hash PBKDF2 real
  const salt = _pbkdf2.newSalt();
  const hash = _pbkdf2.pbkdf2Hash("secret123", salt);
  await db.doc("condominios/QA").set({ nombre: "QA" });
  await db.doc("condominios/QA/casas/101").set({
    numero: 101,
    propietario: "Juan Test",
    residentes: ["Juan", "Ana"],
    passwordHash: _pbkdf2.encodePhc(salt, hash),
  });
  // Casa legacy en texto plano
  await db.doc("condominios/QA/casas/202").set({
    numero: 202,
    propietario: "Plano",
    password: "plain123",
  });

  // 1. Password correcta -> token + datos
  const r1 = await call("loginPropietario", {
    condominio: "QA",
    casaId: "101",
    password: "secret123",
  });
  console.log("login correcto ->", r1.status, JSON.stringify(r1.body).slice(0, 160));
  check("login correcto devuelve token", !!r1.body?.result?.token);
  check("login devuelve propietario correcto", r1.body?.result?.propietario === "Juan Test");
  check("login devuelve residentes", Array.isArray(r1.body?.result?.residentes) && r1.body.result.residentes.length === 2);

  // 2. Password incorrecta -> UNAUTHENTICATED
  const r2 = await call("loginPropietario", {
    condominio: "QA",
    casaId: "101",
    password: "WRONG",
  });
  check("password incorrecta -> UNAUTHENTICATED", r2.body?.error?.status === "UNAUTHENTICATED");

  // 3. Legacy plano -> login OK + re-hash transparente
  const r3 = await call("loginPropietario", {
    condominio: "QA",
    casaId: "202",
    password: "plain123",
  });
  check("legacy plano login OK", !!r3.body?.result?.token);
  const casa202 = (await db.doc("condominios/QA/casas/202").get()).data();
  check(
    "legacy plano re-hasheado a pbkdf2 (sin texto plano)",
    (casa202.passwordHash || "").startsWith("pbkdf2$") && !casa202.password,
  );

  // 4. Casa inexistente -> NOT_FOUND
  const r4 = await call("loginPropietario", {
    condominio: "QA",
    casaId: "999",
    password: "x",
  });
  check("casa inexistente -> NOT_FOUND", r4.body?.error?.status === "NOT_FOUND");

  console.log(`\nQA_LOGIN_RESULT: ${pass} passed, ${fail} failed`);
  process.exit(fail > 0 ? 1 : 0);
})().catch((e) => {
  console.error("HARNESS_ERR", e && e.stack ? e.stack : e);
  process.exit(2);
});
