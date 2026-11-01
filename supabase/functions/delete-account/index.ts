// Edge Function: borra la cuenta de quien llama (requisito de Google Play).
//
//  * Empleado, o gerente con otro gerente activo: se borra solo su cuenta.
//    Su perfil, fichajes, mensajes y avisos se eliminan en cascada; sus
//    fotos de evidencia se borran del almacenamiento.
//  * Único gerente activo: se borra la empresa completa con todos sus
//    datos, fotos y usuarios.
//
// Usa la service role (solo existe aquí, en el servidor).
//
// Deploy:  supabase functions deploy delete-account
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

const BUCKET = "work-evidence";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/// Borra todos los archivos bajo una carpeta del bucket (y sus subcarpetas).
async function removeFolder(admin: SupabaseClient, prefix: string) {
  for (;;) {
    const { data, error } = await admin.storage
      .from(BUCKET)
      .list(prefix, { limit: 1000 });
    if (error || !data || data.length === 0) return;
    const files: string[] = [];
    for (const item of data) {
      const path = `${prefix}/${item.name}`;
      // Las carpetas no tienen id.
      if (item.id === null) await removeFolder(admin, path);
      else files.push(path);
    }
    if (files.length === 0) return;
    await admin.storage.from(BUCKET).remove(files);
    if (data.length < 1000) return;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json(401, { error: "not_authenticated" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ¿Quién llama? Se valida su JWT; nunca se confía en el body.
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json(401, { error: "not_authenticated" });
  const uid = userData.user.id;

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: me } = await admin
    .from("profiles")
    .select("org_id, role, status")
    .eq("id", uid)
    .maybeSingle();

  try {
    if (me && me.role === "manager" && me.status === "active") {
      const { count } = await admin
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("org_id", me.org_id)
        .eq("role", "manager")
        .eq("status", "active")
        .neq("id", uid);

      if ((count ?? 0) === 0) {
        // Único gerente: se borra la empresa completa.
        await removeFolder(admin, me.org_id);
        const { data: ids, error } = await admin.rpc("purge_organization", {
          p_org: me.org_id,
        });
        if (error) throw error;
        for (const id of (ids as string[] | null) ?? []) {
          await admin.auth.admin.deleteUser(id);
        }
        return json(200, { deleted: "organization" });
      }
    }

    // Solo esta cuenta.
    if (me) await removeFolder(admin, `${me.org_id}/${uid}`);
    const { error } = await admin.auth.admin.deleteUser(uid);
    if (error) throw error;
    return json(200, { deleted: "account" });
  } catch (_) {
    // No se devuelve el mensaje interno; solo un código.
    return json(500, { error: "delete_failed" });
  }
});
