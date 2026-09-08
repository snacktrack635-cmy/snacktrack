# Supabase Edge Functions for SnackTrack

This document contains the complete source code and deployment instructions for the Supabase Edge Functions used by SnackTrack:
1. **`generate-recipe`** — Gemini recipe name generation, database check, full recipe creation, and recipes table population.
2. **`scan-food-item`** — Multimodal food item scanning and approximate shelf-life prediction.

---

# 1. Supabase Edge Function: `generate-recipe`

### 📁 File Location / Supabase Dashboard
- **Path:** `supabase/functions/generate-recipe/index.ts`
- **Dashboard Paste:** This file is fully self-contained (all shared logic inlined) and can be pasted directly into the Supabase Dashboard's function editor.

### 🧠 Logic Flow & Prompts
1. **Authentication & Quota Check:** Validates user JWT and checks monthly limit in `usage_counters` against their subscription tier (`free`, `plus`, `pro`).
2. **Pantry Context:** Loads the primary tapped pantry item and unexpired secondary pantry items.
3. **Prompt 1 (Recipe Name Generation):**
   - Gemini is asked to propose a single, creative, realistic recipe title where the primary ingredient is the star.
   - Example prompt:
     `You are an expert chef. Propose ONE delicious, realistic, home-cooked recipe name (dish title) where "${primaryIngredient}" is the main featured ingredient... Return strict JSON with a single field "recipe_name".`
4. **Database Check (`recipes` table):**
   - Checks if a recipe with `normalized_name = lower(recipe_name)` (or matching `name`) already exists in the `recipes` table.
   - **Cache Hit:** If found, increments `generation_count` and immediately returns the cached database recipe with its full ingredients and instructions.
5. **Prompt 2 (Full Recipe Generation):**
   - **Cache Miss:** If not in the database, Gemini generates the full recipe including detailed ingredient quantities and ordered cooking instructions.
   - Example prompt:
     `Create a complete, realistic step-by-step home-cooking recipe for "${recipeName}". The main ingredient is "${primaryIngredient}". Prefer using these other pantry items... Return strict JSON with name, ingredients[], and instructions[].`
6. **Populate `recipes` Table:**
   - The newly generated full recipe is inserted/upserted into `recipes` with `source: 'gemini'`.
7. **Bump Usage Counter:**
   - Increments `usage_counters.recipes_generated`.
8. **Client Response:**
   - Returns both `{ recipe: { ... }, cacheHit }` and root-level fields, ensuring the Flutter client renders the full recipe screen.

---

### 💻 Source Code: `generate-recipe/index.ts`

```typescript
// POST /generate-recipe
// Body: { "pantryItemId": "uuid" } or { "primary_ingredient": "name", "pantryItemId": "uuid" }
//
// DASHBOARD-DEPLOY VERSION: all shared logic inlined into this one file so
// it can be pasted directly into the Supabase Dashboard's function editor,
// which does not bundle sibling _shared/ folders across functions.
//
// Flow:
// 1. Verify user & subscription quota
// 2. Load pantry item (primary) and remaining pantry items (secondary)
// 3. Prompt Gemini to generate a recipe name
// 4. Check if the recipe exists in the `recipes` table:
//    - HIT: Increment generation_count and return cached database recipe
//    - MISS: Prompt Gemini to generate the full recipe (ingredients & instructions),
//      insert into `recipes` table, bump usage counters, and return
// 5. User receives full recipe with name, ingredients, and instructions.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// ============ inlined: cors ============
const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ============ inlined: supabaseAdmin ============
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

function getAdminClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
}

async function getAuthedUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw { status: 401, message: "Missing Authorization header" };

  const client = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw { status: 401, message: "Invalid or expired session" };

  return { user: data.user, client };
}

// ============ inlined: tierLimits ============
type Tier = "free" | "plus" | "pro";

interface TierLimits {
  scansPerMonth: number;
  batchScanning: boolean;
  recipesPerMonth: number;
}

const TIER_LIMITS: Record<Tier, TierLimits> = {
  free: { scansPerMonth: 3, batchScanning: false, recipesPerMonth: 5 },
  plus: { scansPerMonth: 50, batchScanning: true, recipesPerMonth: 30 },
  pro: { scansPerMonth: Infinity, batchScanning: true, recipesPerMonth: Infinity },
};

function limitsFor(tier: Tier): TierLimits {
  return TIER_LIMITS[tier] ?? TIER_LIMITS.free;
}

// ============ inlined: quota ============
interface QuotaCheck {
  allowed: boolean;
  tier: Tier;
  recipesGeneratedSoFar: number;
  scansUsedSoFar: number;
  monthStartISO: string;
}

async function checkRecipeQuota(admin: SupabaseClient, userId: string): Promise<QuotaCheck> {
  const { data: sub } = await admin
    .from("subscriptions")
    .select("tier")
    .eq("user_id", userId)
    .maybeSingle();

  const tier: Tier = (sub?.tier as Tier) ?? "free";
  const limits = limitsFor(tier);

  const monthStart = new Date();
  monthStart.setUTCDate(1);
  monthStart.setUTCHours(0, 0, 0, 0);
  const monthStartISO = monthStart.toISOString().slice(0, 10);

  const { data: usage } = await admin
    .from("usage_counters")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  const isStale = !usage || new Date(usage.period_start) < monthStart;
  const recipesGeneratedSoFar = isStale ? 0 : usage!.recipes_generated;
  const scansUsedSoFar = isStale ? 0 : usage!.scans_used ?? 0;

  return {
    allowed: recipesGeneratedSoFar < limits.recipesPerMonth,
    tier,
    recipesGeneratedSoFar,
    scansUsedSoFar,
    monthStartISO,
  };
}

async function bumpRecipeUsage(admin: SupabaseClient, userId: string, quota: QuotaCheck): Promise<void> {
  await admin.from("usage_counters").upsert(
    {
      user_id: userId,
      period_start: quota.monthStartISO,
      recipes_generated: quota.recipesGeneratedSoFar + 1,
      scans_used: quota.scansUsedSoFar,
    },
    { onConflict: "user_id" },
  );
}

// ============ inlined: gemini ============
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";

async function queryGemini(payload: unknown): Promise<string> {
  if (!GEMINI_API_KEY) {
    throw new Error("GEMINI_API_KEY secret is not set. Run 'supabase secrets set GEMINI_API_KEY=...'");
  }

  const preferredModel = Deno.env.get("GEMINI_MODEL") || "gemini-3.5-flash";
  const candidateModels = [
    preferredModel,
    "gemini-2.5-flash",
    "gemini-1.5-flash",
    "gemini-1.5-pro",
  ];
  const models = [...new Set(candidateModels)];

  let lastError = "";

  for (const model of models) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        const data = await res.json();
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) return text;
      } else {
        const errText = await res.text();
        lastError = `Model ${model} returned ${res.status}: ${errText}`;
        console.warn(`[Gemini] ${lastError}`);
      }
    } catch (e: unknown) {
      lastError = e instanceof Error ? e.message : String(e);
      console.warn(`[Gemini] Network error with model ${model}: ${lastError}`);
    }
  }

  throw new Error(`All Gemini models failed. Last error: ${lastError}`);
}

// Schema 1: Recipe Name Only
const RECIPE_NAME_SCHEMA = {
  type: "object",
  properties: {
    recipe_name: { type: "string" },
  },
  required: ["recipe_name"],
};

// Prompt 1: Generate Recipe Name
async function generateRecipeName(
  primaryIngredient: string,
  availableIngredients: string[],
): Promise<string> {
  const prompt = availableIngredients.length > 0
    ? `You are an expert chef. Propose ONE delicious, realistic, home-cooked recipe name (dish title) where "${primaryIngredient}" is the main featured ingredient. ` +
      `You can consider these other available pantry ingredients if they complement the dish: ${availableIngredients.join(", ")}. ` +
      `Return strict JSON with a single field "recipe_name". Example: {"recipe_name": "Garlic Butter Chicken Breast"}. ` +
      `Keep the title concise, recognizable, and appetizing. Do not return "Untitled Recipe".`
    : `You are an expert chef. Propose ONE delicious, realistic, home-cooked recipe name (dish title) where "${primaryIngredient}" is the star ingredient. ` +
      `Return strict JSON with a single field "recipe_name". Example: {"recipe_name": "Classic Banana Bread"}. ` +
      `Keep the title concise, recognizable, and appetizing. Do not return "Untitled Recipe".`;

  const payload = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RECIPE_NAME_SCHEMA,
      temperature: 0.7,
    },
  };

  const text = await queryGemini(payload);
  try {
    const cleaned = text.replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/\s*```$/i, "").trim();
    const parsed = JSON.parse(cleaned);
    const name = parsed.recipe_name || parsed.name;
    if (typeof name === "string" && name.trim().length > 0) {
      return name.trim();
    }
  } catch {
    const match = text.match(/"recipe_name"\s*:\s*"([^"]+)"/i) || text.match(/"name"\s*:\s*"([^"]+)"/i);
    if (match && match[1]) {
      return match[1].trim();
    }
  }

  // Fallback if parsing failed
  return `${primaryIngredient.charAt(0).toUpperCase() + primaryIngredient.slice(1)} Delight`;
}

// Schema 2: Full Recipe Details
interface GeneratedRecipe {
  name: string;
  ingredients: { name: string; quantity: string }[];
  instructions: string[];
}

const RECIPE_RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: { name: { type: "string" }, quantity: { type: "string" } },
        required: ["name", "quantity"],
      },
    },
    instructions: { type: "array", items: { type: "string" } },
  },
  required: ["name", "ingredients", "instructions"],
};

// Prompt 2: Generate Full Recipe (Ingredients & Instructions)
async function generateFullRecipe(
  recipeName: string,
  primaryIngredient: string,
  availableIngredients: string[],
): Promise<GeneratedRecipe> {
  const prompt = availableIngredients.length > 0
    ? `Create a complete, realistic step-by-step home-cooking recipe for "${recipeName}". ` +
      `The main ingredient is "${primaryIngredient}". ` +
      `Prefer using these other pantry items where it makes culinary sense: ${availableIngredients.join(", ")}. ` +
      `You may also include common pantry staples (salt, pepper, oil, water, butter, flour, sugar) as needed. ` +
      `Provide specific ingredient measurements and clear, numbered preparation steps.`
    : `Create a complete, realistic step-by-step home-cooking recipe for "${recipeName}" using "${primaryIngredient}" as the main ingredient. ` +
      `Assume common pantry staples (salt, pepper, oil, water, butter, flour, sugar) are available. ` +
      `Provide specific ingredient measurements and clear, numbered preparation steps.`;

  const payload = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RECIPE_RESPONSE_SCHEMA,
      temperature: 0.7,
    },
  };

  const text = await queryGemini(payload);
  let parsed: GeneratedRecipe;
  try {
    const cleaned = text.replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/\s*```$/i, "").trim();
    parsed = JSON.parse(cleaned);
  } catch {
    throw new Error("Gemini returned malformed JSON for full recipe");
  }

  if (!parsed.name || parsed.name.trim().length === 0 || parsed.name.toLowerCase() === "untitled recipe") {
    parsed.name = recipeName;
  }

  if (!Array.isArray(parsed.ingredients) || parsed.ingredients.length === 0) {
    parsed.ingredients = [{ name: primaryIngredient, quantity: "1 serving" }];
  }

  if (!Array.isArray(parsed.instructions) || parsed.instructions.length === 0) {
    parsed.instructions = ["Prepare ingredients and cook until done."];
  }

  return parsed;
}

// ============ function body ============
Deno.serve(async (req: Request) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  try {
    const { user, client: userClient } = await getAuthedUser(req);
    const body = await req.json();
    const pantryItemId = body.pantryItemId || body.pantry_item_id;
    let primaryName = (body.primary_ingredient || body.primaryIngredient || "").trim().toLowerCase();

    if (!pantryItemId && !primaryName) {
      return jsonResponse({ error: "pantryItemId or primary_ingredient is required" }, 400);
    }

    const admin = getAdminClient();

    // 1. Quota check
    const quota = await checkRecipeQuota(admin, user.id);
    if (!quota.allowed) {
      return jsonResponse(
        { error: "quota_exceeded", message: "Monthly recipe generation limit reached." },
        403,
      );
    }

    // 2. Fetch primary pantry item if ID is provided
    if (pantryItemId) {
      const { data: primaryItem, error: primaryError } = await userClient
        .from("pantry_items")
        .select("id, name")
        .eq("id", pantryItemId)
        .single();

      if (primaryItem && primaryItem.name) {
        primaryName = primaryItem.name.trim().toLowerCase();
      }
    }

    if (!primaryName) {
      return jsonResponse({ error: "Pantry item not found or has no name" }, 404);
    }

    // 3. Fetch secondary pantry items (non-expired)
    const today = new Date().toISOString().slice(0, 10);
    let query = userClient
      .from("pantry_items")
      .select("name")
      .or(`expiry_date.is.null,expiry_date.gte.${today}`)
      .order("expiry_date", { ascending: true })
      .limit(30);

    if (pantryItemId) {
      query = query.neq("id", pantryItemId);
    }

    const { data: pantryRest } = await query;
    const pantryNames = (pantryRest ?? [])
      .map((p) => p.name.trim().toLowerCase())
      .filter((n) => n !== primaryName);

    // 4. STEP A: Generate recipe name via Gemini
    const recipeName = await generateRecipeName(primaryName, pantryNames.slice(0, 15));
    const normalizedName = recipeName.trim().toLowerCase();

    // 5. STEP B: Check if recipe exists in the database
    // Check 1: by normalized_name
    let { data: existingRecipe } = await admin
      .from("recipes")
      .select("*")
      .eq("normalized_name", normalizedName)
      .limit(1)
      .maybeSingle();

    // Check 2: by name (case-insensitive)
    if (!existingRecipe) {
      const { data: byName } = await admin
        .from("recipes")
        .select("*")
        .ilike("name", recipeName.trim())
        .limit(1)
        .maybeSingle();
      existingRecipe = byName;
    }

    let recipe;
    let cacheHit = false;

    if (existingRecipe) {
      // Recipe exists in the database table!
      cacheHit = true;
      const { data: updated } = await admin
        .from("recipes")
        .update({ generation_count: (existingRecipe.generation_count || 1) + 1 })
        .eq("id", existingRecipe.id)
        .select()
        .single();

      recipe = updated ?? existingRecipe;
    } else {
      // Recipe does NOT exist in the database table!
      cacheHit = false;

      // STEP C: Generate the full recipe (ingredients & instructions) with Gemini
      const fullRecipe = await generateFullRecipe(recipeName, primaryName, pantryNames.slice(0, 15));

      // STEP D: Populate the recipes table
      const { data: inserted, error: insertError } = await admin
        .from("recipes")
        .upsert(
          {
            name: fullRecipe.name,
            ingredients: fullRecipe.ingredients,
            instructions: fullRecipe.instructions,
            primary_ingredient: primaryName,
            source: "gemini",
            generation_count: 1,
          },
          { onConflict: "normalized_name,primary_ingredient", ignoreDuplicates: false },
        )
        .select()
        .single();

      if (insertError) {
        console.error("Upsert recipe error, falling back to select:", insertError);
        const { data: fallback } = await admin
          .from("recipes")
          .select("*")
          .eq("normalized_name", normalizedName)
          .maybeSingle();

        recipe = fallback ?? {
          id: crypto.randomUUID(),
          name: fullRecipe.name,
          ingredients: fullRecipe.ingredients,
          instructions: fullRecipe.instructions,
          primary_ingredient: primaryName,
          source: "gemini",
          generation_count: 1,
          created_at: new Date().toISOString(),
        };
      } else {
        recipe = inserted;
      }
    }

    // 6. Bump user usage counter
    await bumpRecipeUsage(admin, user.id, quota);

    // 7. Return recipe both in nested 'recipe' field and top-level fields for client compatibility
    return jsonResponse({
      recipe,
      cacheHit,
      id: recipe.id,
      name: recipe.name,
      normalized_name: recipe.normalized_name,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
      primary_ingredient: recipe.primary_ingredient,
      source: recipe.source,
      generation_count: recipe.generation_count,
      created_at: recipe.created_at,
    });
  } catch (err) {
    const status = (err as { status?: number })?.status ?? 500;
    const message = (err as { message?: string })?.message ?? "Unexpected error";
    console.error("generate-recipe error:", err);
    return jsonResponse({ error: message }, status);
  }
});
```

---

# 2. Supabase Edge Function: `scan-food-item`

### 📁 File Location
```
supabase/functions/scan-food-item/index.ts
```

### 💻 Source Code (`index.ts`)

```typescript
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class GeminiApiError extends Error {
  status: number;
  constructor(message: string, status = 502) {
    super(message);
    this.name = "GeminiApiError";
    this.status = status;
  }
}

function sanitizeBase64(raw: string): string {
  if (raw.includes("base64,")) {
    return raw.split("base64,")[1].trim();
  }
  return raw.trim();
}

function extractAndParseJson(text: string): Record<string, unknown> {
  const cleaned = text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start !== -1 && end !== -1 && end > start) {
      return JSON.parse(cleaned.substring(start, end + 1));
    }
    throw new Error(`Failed to parse valid JSON from AI output: ${text.slice(0, 100)}...`);
  }
}

async function queryGemini(apiKey: string, payload: unknown) {
  const preferredModel = Deno.env.get("GEMINI_MODEL") || "gemini-3.5-flash-lite";
  const candidateModels = [
    preferredModel,
    "gemini-3.8-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.7-flash",
    "gemini-2.5-flash",
  ];
  const models = [...new Set(candidateModels)];

  let lastStatus = 500;
  let lastErrorText = "";

  for (const model of models) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        return await res.json();
      }

      lastStatus = res.status;
      lastErrorText = await res.text();
      console.warn(`[Gemini] Model "${model}" failed with status ${res.status}: ${lastErrorText}`);

      // If high demand (503), rate limited (429), or model not found (404), fail over to next model
      if (res.status === 503 || res.status === 429 || res.status === 404) {
        continue;
      }
      break;
    } catch (e: unknown) {
      lastErrorText = e instanceof Error ? e.message : String(e);
      console.warn(`[Gemini] Network error for model "${model}": ${lastErrorText}`);
    }
  }

  throw new GeminiApiError(`All Gemini models failed. Last error (${lastStatus}): ${lastErrorText}`, 502);
}

Deno.serve(async (req: Request) => {
  // 1. Handle CORS preflight options
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 2. Validate Gemini API Key
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          error:
            "GEMINI_API_KEY secret is not set. Run 'supabase secrets set GEMINI_API_KEY=...' to configure.",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const body = await req.json();
    const mode = body.mode || "vision_scan";

    // -------------------------------------------------------------
    // MODE 1: Multimodal Vision Scan (Image -> Food item & Expiry)
    // -------------------------------------------------------------
    if (mode === "vision_scan") {
      const { image, mime_type = "image/jpeg" } = body;

      if (!image) {
        return new Response(
          JSON.stringify({ error: "Missing required 'image' (base64 string)." }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const prompt = `You are an expert food safety, grocery inventory, and shelf-life prediction assistant.
Analyze the provided image of a food item and respond with a strict JSON object (and nothing else):
{
  "name": "Specific food item name (e.g., Honeycrisp Apples, Whole Milk, Sourdough Bread)",
  "category": "One of: Produce, Dairy, Meat & Seafood, Bakery, Pantry, Frozen, Beverages, Snacks, Other",
  "days_until_expiry": 7,
  "confidence": 0.95,
  "freshness_notes": "Visual condition notes (e.g., firm skin, no bruising, peak ripeness)",
  "suggested_storage": "One of: refrigerator, pantry, freezer",
  "estimated_quantity": 1.0,
  "estimated_unit": "pcs, bunch, bottle, loaf, kg, or g"
}`;

      const payload = {
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mime_type,
                  data: sanitizeBase64(image),
                },
              },
            ],
          },
        ],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.2,
        },
      };

      const geminiData = await queryGemini(apiKey, payload);
      const rawText =
        geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!rawText) {
        const blockReason = geminiData.promptFeedback?.blockReason ?? "Empty response";
        return new Response(
          JSON.stringify({ error: `No output generated from Gemini vision (${blockReason}).` }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const parsed = extractAndParseJson(rawText);
      return new Response(JSON.stringify(parsed), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // -------------------------------------------------------------
    // MODE 2: Text Shelf-Life Estimation (Item Name -> Expiry)
    // -------------------------------------------------------------
    if (mode === "text_estimate") {
      const { name, category, storage_location } = body;

      if (!name) {
        return new Response(
          JSON.stringify({ error: "Missing required 'name' field." }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const prompt = `Estimate shelf life for food item: "${name}", category: "${category || "unknown"}", storage: "${storage_location || "unknown"}".
Return strict JSON:
{
  "name": "${name}",
  "category": "${category || "Produce"}",
  "days_until_expiry": 7,
  "confidence": 0.85,
  "freshness_notes": "Estimated shelf life guidelines",
  "suggested_storage": "${storage_location || "refrigerator"}",
  "estimated_quantity": 1.0,
  "estimated_unit": "pcs"
}`;

      const payload = {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.2,
        },
      };

      const geminiData = await queryGemini(apiKey, payload);
      const rawText =
        geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!rawText) {
        return new Response(
          JSON.stringify({ error: "No output generated from Gemini text estimation." }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const parsed = extractAndParseJson(rawText);
      return new Response(JSON.stringify(parsed), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ error: `Unsupported mode: ${mode}` }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof GeminiApiError
      ? err.message
      : err instanceof Error
        ? err.message
        : "Internal server error";
    const status = err instanceof GeminiApiError ? err.status : 500;

    return new Response(
      JSON.stringify({ error: errorMsg }),
      {
        status: status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
```

---

## 🚀 Deployment Instructions

### 1. Link Supabase Project
```bash
supabase link --project-ref tmckkcgymgdunakhdywj
```

### 2. Configure Secret
```bash
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

### 3. Deploy Functions
```bash
supabase functions deploy generate-recipe
supabase functions deploy scan-food-item
```
*(Or paste the full inlined `generate-recipe` script directly into Supabase Dashboard -> Edge Functions -> Create Function)*.
