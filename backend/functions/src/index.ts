// =============================================================================
// FortGuards - Cloud Functions entry point
// =============================================================================
import { initializeApp, getApps } from "firebase-admin/app";
if (getApps().length === 0) initializeApp();

// Importa todos los módulos
export * from "./auth";
export * from "./qr";
export * from "./notifications";
export * from "./scheduled";

console.log("✅ FortGuards Cloud Functions cargadas");
