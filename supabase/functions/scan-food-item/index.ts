import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY secret is not configured in Supabase Edge Functions.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json();
    const mode = body.mode || 'vision_scan';

    if (mode === 'vision_scan') {
      const { image, mime_type = 'image/jpeg' } = body;
      if (!image) {
        return new Response(
          JSON.stringify({ error: 'Missing base64 image data.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const prompt = `You are an expert food safety, grocery inventory, and shelf-life prediction assistant.
Analyze the provided image of a food item and respond with a strict JSON object (and nothing else):
{
  "name": "Food item name (e.g., Honeycrisp Apples, Whole Milk, Sourdough Bread)",
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
          response_mime_type: 'application/json',
          temperature: 0.2,
        },
      };

      const geminiRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!geminiRes.ok) {
        const errText = await geminiRes.text();
        return new Response(
          JSON.stringify({ error: `Gemini API error (${geminiRes.status}): ${errText}` }),
          { status: geminiRes.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const geminiData = await geminiRes.json();
      const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!rawText) {
        return new Response(
          JSON.stringify({ error: 'No output generated from Gemini vision.' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
      const parsed = JSON.parse(cleanJson);

      return new Response(
        JSON.stringify(parsed),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (mode === 'text_estimate') {
      const { name, category, storage_location } = body;
      const prompt = `Estimate shelf life for food item: "${name}", category: "${category || 'unknown'}", storage: "${storage_location || 'unknown'}".
Return strict JSON:
{
  "name": "${name}",
  "category": "${category || 'Produce'}",
  "days_until_expiry": 7,
  "confidence": 0.85,
  "freshness_notes": "Estimated shelf life guidelines",
  "suggested_storage": "${storage_location || 'refrigerator'}",
  "estimated_quantity": 1.0,
  "estimated_unit": "pcs"
}`;

      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;
      const payload = {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { response_mime_type: 'application/json', temperature: 0.2 },
      };

      const geminiRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const geminiData = await geminiRes.json();
      const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
      const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
      const parsed = JSON.parse(cleanJson);

      return new Response(
        JSON.stringify(parsed),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: `Unsupported mode: ${mode}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
