// Edge Function: invita a un empleado a la organización del gerente que
// llama. Usa la service role (solo existe aquí, en el servidor; nunca en la
// app) para enviar el correo de invitación y crear el perfil 'invited'.
//
// Deploy:  supabase functions deploy invite-employee
// Secret:  supabase secrets set INVITE_REDIRECT_URL=<deep link de la app>
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

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

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json(401, { error: "not_authenticated" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1. ¿Quién llama? Se valida el JWT del usuario, no se confía en el body.
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json(401, { error: "not_authenticated" });

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: caller } = await admin
    .from("profiles")
    .select("org_id, role, status")
    .eq("id", userData.user.id)
    .single();
  if (!caller || caller.role !== "manager" || caller.status !== "active") {
    return json(403, { error: "not_allowed" });
  }

  // 2. Validar entrada.
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "invalid_body" });
  }
  const email = String(body.email ?? "").trim().toLowerCase();
  const fullName = String(body.full_name ?? "").trim();
  const positionEs = String(body.position_es ?? "").trim();
  const positionEn = String(body.position_en ?? positionEs).trim();
  const hourlyRate = Number(body.hourly_rate ?? 0);
  const role = body.role === "manager" ? "manager" : "employee";

  if (!EMAIL_RE.test(email) || email.length > 254) {
    return json(400, { error: "invalid_email" });
  }
  if (fullName.length < 1 || fullName.length > 120) {
    return json(400, { error: "invalid_name" });
  }
  if (positionEs.length > 60 || positionEn.length > 60) {
    return json(400, { error: "invalid_position" });
  }
  if (!Number.isFinite(hourlyRate) || hourlyRate < 0 || hourlyRate > 10_000_000) {
    return json(400, { error: "invalid_rate" });
  }

  // 3. Invitar y crear el perfil.
  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
    email,
    { redirectTo: Deno.env.get("INVITE_REDIRECT_URL") ?? undefined },
  );
  if (inviteError || !invited.user) {
    // No se devuelve el mensaje interno; solo un código.
    const exists = inviteError?.message?.toLowerCase().includes("already") ?? false;
    return json(exists ? 409 : 500, { error: exists ? "already_registered" : "invite_failed" });
  }

  const { error: profileError } = await admin.from("profiles").insert({
    id: invited.user.id,
    org_id: caller.org_id,
    full_name: fullName,
    email,
    role,
    position_es: positionEs,
    position_en: positionEn,
    hourly_rate: hourlyRate,
    status: "invited",
    avatar_index: Math.floor(Math.random() * 5),
  });
  if (profileError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    return json(500, { error: "invite_failed" });
  }

  return json(200, { id: invited.user.id });
});
