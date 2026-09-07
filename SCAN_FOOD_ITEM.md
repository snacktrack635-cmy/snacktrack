# Supabase Edge Function: `scan-food-item`

This document contains the complete source code and deployment instructions for the **`scan-food-item`** Supabase Edge Function used by SnackTrack.

---

## 📁 File Location

Place this file at:
```
supabase/functions/scan-food-item/index.ts
```

---

## 💻 Source Code (`index.ts`)

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
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

      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

      const payload = {
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mime_type,
                  data: image,
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

      const response = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errorText = await response.text();
        return new Response(
          JSON.stringify({
            error: `Gemini API returned ${response.status}: ${errorText}`,
          }),
          {
            status: response.status,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const geminiData = await response.json();
      const rawText =
        geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!rawText) {
        return new Response(
          JSON.stringify({ error: "Gemini returned empty response for this image." }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const cleanJson = rawText
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();
      const parsed = JSON.parse(cleanJson);

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

      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

      const payload = {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.2,
        },
      };

      const response = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const geminiData = await response.json();
      const rawText =
        geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
      const cleanJson = rawText
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();
      const parsed = JSON.parse(cleanJson);

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
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
```

---

## 🚀 Deployment Instructions

### 1. Link your Supabase project (if not already linked)
```bash
supabase link --project-ref tmckkcgymgdunakhdywj
```

### 2. Set your Google Gemini API key as a secret
Get an API key from [Google AI Studio](https://aistudio.google.com/), then run:
```bash
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

### 3. Deploy the Edge Function
```bash
supabase functions deploy scan-food-item
```

*(Optional: if testing without authentication headers, add `--no-verify-jwt`)*:
```bash
supabase functions deploy scan-food-item --no-verify-jwt
```

---

## 🧪 Testing the Function

### Test via cURL (Text Estimation Mode):
```bash
curl -i --location --request POST 'https://tmckkcgymgdunakhdywj.supabase.co/functions/v1/scan-food-item' \
  --header 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "mode": "text_estimate",
    "name": "Strawberries",
    "category": "Produce",
    "storage_location": "refrigerator"
  }'
```

### Expected Output:
```json
{
  "name": "Strawberries",
  "category": "Produce",
  "days_until_expiry": 4,
  "confidence": 0.9,
  "freshness_notes": "Estimated shelf life guidelines",
  "suggested_storage": "refrigerator",
  "estimated_quantity": 1.0,
  "estimated_unit": "bunch"
}
```
