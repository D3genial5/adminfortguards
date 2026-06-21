// =============================================================================
// FortGuards - Cloud Functions entry point
// deploy-bump: rebind Firestore triggers a la base (default) nam5 (2026-06)
// =============================================================================
import { initializeApp, getApps } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";
if (getApps().length === 0) initializeApp();

// Cap global de instancias: el proyecto tiene cuota baja de CPU/region
// (20 CPU). Con 18 funciones, maxInstances=1 mantiene el total dentro de cuota.
// Subir por-funcion cuando se aumente la cuota del proyecto de produccion.
setGlobalOptions({ maxInstances: 1 });

// Importa todos los módulos
export * from "./auth";
export * from "./qr";
export * from "./notifications";
export * from "./scheduled";
