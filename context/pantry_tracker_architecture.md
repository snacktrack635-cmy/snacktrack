# Pantry Tracker — Architecture & Structure

**Stack:** Flutter (Riverpod) · Supabase (Postgres, Auth, Storage, Edge Functions) · Google Gemini (recipe generation, AI food item vision & expiry prediction) · Stripe (subscriptions)

---

## 0. Important Note on Stripe + Mobile

Apple and Google require **in-app digital subscriptions** to go through StoreKit / Play Billing in most cases — a mobile app that sells subscription access to app features via Stripe checkout risks rejection or removal. Common ways around this, pick one before you build the billing layer:

- **Reader-app / external purchase pattern**: subscription is purchased on your website, the app only *checks entitlement* via your backend (works cleanly for content-style apps, riskier for "utility" apps like this).
- **Use Stripe for the backend/ledger, but gate the actual mobile purchase through RevenueCat or native IAP**, and reconcile both to the same `subscriptions` table.
- **Distribute outside the stores** (web app / PWA / sideload) if that's viable for your audience.

The schema below is store-agnostic (a `subscriptions` table keyed by user + provider), so you can swap or dual-run providers without a rewrite. I'd revisit this before submitting to the App Store.

---

## 1. High-Level Architecture

```
┌─────────────────────────┐
│      Flutter App        │
│  (Riverpod, feature-    │
│   first architecture)   │
└───────────┬──────────────┘
            │ supabase_flutter SDK
            ▼
┌─────────────────────────┐        ┌──────────────────────┐
│   Supabase Postgres      │◄──────►│  Row Level Security   │
│   (pantry, recipes,      │        │  per-user isolation   │
│    shopping list, subs)  │        └──────────────────────┘
            │
            ▼
┌─────────────────────────┐        ┌──────────────────────────────────┐
│  Supabase Edge Functions │───────►│  Google Gemini API               │
│  (Deno) — business logic │        │  - recipe generation             │
│  recipe cache lookup,    │        │  - multimodal food item vision   │
│  expiry heuristics,      │        │  - dynamic shelf-life estimation │
│  Stripe webhooks,        │        └──────────────────────────────────┘
│  usage/quota checks      │        ┌──────────────────────────────────┐
└──────────────────────────┘───────►│  Open Food Facts API             │
                                    │  (barcode → product)             │
                                    └──────────────────────────────────┘
```

**Why Edge Functions, not client-side calls:** the Gemini API key, recipe-dedup logic, and quota enforcement must never live on-device (users can decompile/intercept an APK and bypass tier limits or drain your API key). All AI calls (recipe generation and multimodal food item scanning/expiry prediction), Stripe webhook handling, and quota checks go through Edge Functions (or authenticated Gemini services).

---

## 2. Flutter Project Structure (Feature-First + Riverpod)

```
lib/
├── main.dart
├── app.dart                      # MaterialApp, router, theme
├── core/
│   ├── constants/                # colors, spacing, tier limits
│   ├── router/                   # go_router config + route guards
│   ├── theme/
│   ├── utils/                    # date formatting, debouncers, etc.
│   ├── errors/                   # Failure types, exception mapping
│   ├── services/                 # AI & infrastructure services
│   │   └── gemini_service.dart   # Gemini multimodal food scanner & shelf-life predictor
│   └── network/
│       └── supabase_client.dart  # singleton client + interceptor-like helpers
│
├── data/
│   ├── models/                   # freezed + json_serializable models
│   │   ├── pantry_item.dart
│   │   ├── ai_food_scan_result.dart # Gemini food scan & expiry detection model
│   │   ├── recipe.dart
│   │   ├── shopping_list_item.dart
│   │   ├── subscription.dart
│   │   └── user_profile.dart
│   ├── repositories/             # talk to Supabase, one per domain
│   │   ├── pantry_repository.dart
│   │   ├── recipe_repository.dart
│   │   ├── shopping_list_repository.dart
│   │   ├── barcode_repository.dart
│   │   └── subscription_repository.dart
│   └── datasources/
│       ├── supabase_pantry_ds.dart
│       ├── supabase_recipe_ds.dart
│       └── edge_functions_ds.dart   # wraps functions.invoke() calls (recipe gen, AI food scan)
│
├── features/
│   ├── onboarding/
│   │   ├── presentation/ (screens, widgets)
│   │   └── application/ (onboarding_controller.dart — riverpod notifier)
│   ├── pantry/
│   │   ├── presentation/
│   │   │   ├── screens/pantry_list_screen.dart
│   │   │   ├── screens/item_scan_screen.dart # manual review & edit of scanned food item & expiry
│   │   │   └── widgets/pantry_item_card.dart
│   │   └── application/
│   │       ├── pantry_controller.dart
│   │       └── expiry_prediction_controller.dart
│   ├── scanning/
│   │   ├── presentation/screens/barcode_scan_screen.dart
│   │   ├── presentation/screens/photo_scan_screen.dart
│   │   ├── presentation/screens/ai_food_scan_screen.dart # Camera/photo capture for Gemini AI food scanning
│   │   └── application/scan_controller.dart              # manages barcode, label OCR & Gemini AI scan states
│   ├── recipes/
│   │   ├── presentation/
│   │   │   ├── screens/recipe_list_screen.dart
│   │   │   ├── screens/recipe_detail_screen.dart
│   │   │   └── screens/expiring_soon_recipes_screen.dart
│   │   └── application/
│   │       ├── recipe_generation_controller.dart
│   │       └── favorites_controller.dart
│   ├── shopping_list/
│   │   ├── presentation/
│   │   └── application/shopping_list_controller.dart
│   ├── subscription/
│   │   ├── presentation/screens/paywall_screen.dart
│   │   └── application/subscription_controller.dart
│
├── providers/
│   └── global_providers.dart     # riverpod providers wiring repos & services → controllers
│
└── widgets/                      # shared/dumb widgets (buttons, sheets, loaders)
```

**Why this shape:** feature folders keep each vertical slice self-contained (easy to hand off or delete), `data/` is the only layer that knows about Supabase, and controllers never talk to the network directly — they go through repositories and core services. This keeps widget rebuilds cheap and testable.

---

## 3. Performance Rules (baked into the structure, not bolted on)

| Concern | Approach |
|---|---|
| Scanning UI freeze | Run OCR/ML Kit barcode + label detection in an `Isolate` via `compute()`; camera stream never blocks the UI thread |
| AI Food Scanning (Gemini Vision) | Compress photo on-device (<500KB, max dimension 1024px via `flutter_image_compress`) before transmission; enforce strict JSON response schema for deterministic identification and expiry estimation in ~1-2s |
| Pantry list with many items | Paginate via Supabase `.range()`, use `ListView.builder` + `AutomaticKeepAlive` off, cache images with `cached_network_image` |
| Recipe generation latency | Always check the `recipes` cache table **first** (indexed, normalized-name lookup) before calling Gemini — cache hit returns in ~50–100ms vs ~2–4s for an LLM call |
| Riverpod rebuild storms | Scope providers with `.family`/`.autoDispose`, use `select()` on watched state so a single item update doesn't rebuild the whole list |
| Expiry date sorting | Computed once server-side (or cached client-side) rather than recalculated every frame |
| Cold start | Defer Gemini/Stripe SDK init until first use; lazy-load onboarding assets |
| Image uploads | Compress on-device (`flutter_image_compress`) before upload to Supabase Storage |

---

## 4. Supabase Database Schema

```sql
-- ============ USERS & AUTH ============
-- auth.users is managed by Supabase Auth

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  login_count int not null default 0,
  has_completed_onboarding boolean not null default false,
  created_at timestamptz not null default now()
);

-- ============ SUBSCRIPTIONS ============
create type subscription_tier as enum ('free', 'plus', 'pro');
create type subscription_provider as enum ('stripe', 'apple', 'google');

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  tier subscription_tier not null default 'free',
  provider subscription_provider,
  provider_subscription_id text,        -- Stripe subscription id / store purchase token
  status text not null default 'active', -- active, past_due, canceled
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index on public.subscriptions(user_id);

-- Rolling usage counters, reset monthly by a scheduled Edge Function / cron
create table public.usage_counters (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  period_start date not null default date_trunc('month', now()),
  scans_used int not null default 0,
  recipes_generated int not null default 0
);

-- ============ PANTRY ============
create table public.pantry_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  normalized_name text generated always as (lower(trim(name))) stored,
  barcode text,
  category text,
  quantity numeric default 1,
  unit text,
  expiry_date date,
  expiry_source text default 'predicted', -- predicted | manual | label_ocr | ai_predicted
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.pantry_items(user_id, expiry_date);
create index on public.pantry_items(normalized_name);

-- ============ RECIPES (shared cache + AI replacement dataset) ============
create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text generated always as (lower(trim(name))) stored,
  ingredients jsonb not null,       -- [{ "name": "eggs", "quantity": "2" }, ...]
  instructions jsonb not null,      -- ["step 1", "step 2", ...]
  primary_ingredient text,          -- the pantry item this was generated for
  source text not null default 'gemini', -- gemini | manual | future in-house model
  generation_count int not null default 1, -- how many times this recipe was served (popularity signal)
  created_at timestamptz not null default now()
);
-- Fast, low-latency dedup lookup — this is the "check if recipe exists" index
create unique index recipes_normalized_name_primary_idx
  on public.recipes(normalized_name, primary_ingredient);

create table public.favorite_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  recipe_snapshot jsonb not null,   -- denormalized JSON copy at time of favoriting
  created_at timestamptz not null default now(),
  unique(user_id, recipe_id)
);

-- ============ SHOPPING LIST ============
create table public.shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  quantity numeric default 1,
  unit text,
  is_checked boolean not null default false,
  source text default 'manual',  -- manual | recipe | low_stock
  created_at timestamptz not null default now()
);
```

**Why `recipes` is global, not per-user:** this is the table you'll eventually mine to replace Gemini calls with your own lookup/algorithm. Keeping it deduplicated by `normalized_name + primary_ingredient` means popular staples (e.g. "Garlic Butter Rice") converge to one row with a rising `generation_count`, instead of N near-duplicate rows per user.

**Row Level Security:** every user-owned table (`pantry_items`, `favorite_recipes`, `shopping_list_items`, `usage_counters`, `subscriptions`) gets a policy like:
```sql
alter table public.pantry_items enable row level security;
create policy "Users manage their own pantry items"
  on public.pantry_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```
`recipes` is read-only to authenticated users and write-only via the service role (Edge Functions), since it's shared, not user-owned.

---

## 5. Recipe Generation Flow (latency-first)

This is the core flow the spec asks for — item-triggered, pantry-aware, cached, tier-gated.

```
User taps recipe icon on a pantry item
        │
        ▼
Edge Function: generate-recipe
        │
   1. Check usage_counters vs tier limit → reject early if exhausted (no LLM call wasted)
        │
   2. Fetch user's current pantry_items
        │
   3. Build ingredient pool:
        - primary = tapped item
        - secondary = other non-expired pantry items
        │
   4. Cache lookup:
        SELECT * FROM recipes
        WHERE primary_ingredient = :item
        AND ingredients @> pantry_subset   -- jsonb containment check
        ORDER BY generation_count DESC
        LIMIT 1
        │
        ├── HIT  → increment generation_count, return cached recipe (~50-100ms)
        │
        └── MISS → call Gemini with a structured prompt:
                    "Using {primary} as the main ingredient, prefer these
                     available items: {pantry list}. If insufficient,
                     use {primary} alone in a simple recipe.
                     Return strict JSON: {name, ingredients[], instructions[]}"
                    │
                    ▼
             Validate + normalize JSON response
                    │
                    ▼
             UPSERT into recipes (on conflict normalized_name+primary_ingredient
                                    → increment generation_count)
                    │
                    ▼
             Increment usage_counters.recipes_generated
                    │
                    ▼
             Return recipe to client
```

Same pipeline is reused for **"about to expire" recipes**: instead of one primary ingredient, the Edge Function pulls all `pantry_items` where `expiry_date <= now() + interval '3 days'` and asks Gemini for a recipe that uses as many of them as possible, still cache-checked first by a normalized key of the sorted ingredient set.

**Favoriting:** client calls `favorite_recipes` insert with a JSON snapshot of the recipe (not just a foreign key) — this is what the spec means by "save as JSON, retrieve JSON to feature on frontend." It protects the favorite from ever changing if the shared `recipes` row is later edited/deduped.

---

## 6. Scanning Modes & Expiry Prediction (Barcode, Label OCR & Gemini AI)

The app provides three integrated scanning modalities to capture pantry items:

```
                  ┌───────────────────────────────┐
                  │    User Camera / Capture      │
                  └───────────────┬───────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Barcode Scan     │    │ Printed Label    │    │ Gemini AI Food   │
│ (mobile_scanner) │    │ OCR (ML Kit)     │    │ Item Scanner     │
└─────────┬────────┘    └─────────┬────────┘    └─────────┬────────┘
          │                       │                       │
          ▼                       ▼                       ▼
   Open Food Facts        Regex Date Parser       Gemini 1.5 Flash Vision
   (name, category)       (EXP: DD/MM/YY)         - Identifies food item
          │                       │               - Food category
          │                       │               - Approximate expiry date
          │                       │               - Storage recommendation
          │                       │               - Freshness & quantity
          └───────────────────────┼───────────────────────┘
                                  ▼
                   ┌──────────────────────────────┐
                   │    Item Review & Edit UI     │
                   │    (item_scan_screen.dart)   │
                   │ - Name & category pre-filled │
                   │ - Expiry date pre-filled     │
                   │ - User can edit all fields   │
                   │   manually before saving     │
                   └──────────────┬───────────────┘
                                  ▼
                     Save to pantry_items table
                  (expiry_source: 'ai_predicted'
                   | 'label_ocr' | 'predicted' | 'manual')
```

1. **Barcode Scanning:** `mobile_scanner` package (ML Kit under the hood, on-device, fast, no network round-trip for the scan itself). On successful decode, calls Open Food Facts API for product name/category; falls back to manual entry if not found.
2. **Photo/Label Scanning (OCR):** on-device text recognition (`google_mlkit_text_recognition`) to pull printed expiry dates off packaging when visible; if no date is detected, falls back to a category-based heuristic table stored in Postgres or Gemini estimation.
3. **Gemini AI Multimodal Food Item Scanning:**
   - **Use Case:** Fresh produce, bulk items, leftovers, baked goods, or unpackaged groceries without barcodes or printed dates.
   - **Pipeline:** Camera photo or gallery image is compressed on-device (<500KB) and passed to `GeminiService` (via Edge Function `scan-food-item` with quota gating, or direct API fallback).
   - **Multimodal Model Output:** Gemini (`gemini-1.5-flash`) inspects visual features (ripeness, bruising, texture, packaging) and outputs strict JSON:
     - `name`: identified food item name (e.g., "Honeycrisp Apples", "Sourdough Bread").
     - `category`: standard category (e.g., "Produce", "Bakery", "Dairy").
     - `days_until_expiry`: integer estimate based on item type and visible condition.
     - `confidence`: detection confidence score (0.0–1.0).
     - `freshness_notes`: visual observations (e.g. "Firm with green skin, early ripeness").
     - `suggested_storage`: recommended storage method (e.g. "pantry" vs "refrigerator").
   - **Manual Override:** The user is immediately transitioned to `ItemScanScreen` where all AI-predicted attributes are populated. The user can review, edit the name/category/quantity, and manually adjust the expiry date via a date picker before saving to their pantry.
   - **Provenance Tracking:** Written with `expiry_source: 'ai_predicted'`. If the user manually changes the date, it flips to `'manual'`.

---

## 7. Subscription Tiers & Quota Enforcement

| Tier | Scan limit (Barcode/OCR/AI) | Scan mode | Recipe generations/month |
|---|---|---|---|
| Free | 3/month | single-item only | e.g. 5 |
| Plus | higher cap (e.g. 30/mo) | batch scanning unlocked | e.g. 30 |
| Pro | unlimited | batch scanning | highest / unlimited |

- Limits live in a single `core/constants/tier_limits.dart` on the client (for instant UI feedback / disabling buttons) **and** are re-checked server-side in the Edge Function before any scan/generation is processed — client-side checks are UX only, never trusted for enforcement.
- `usage_counters.scans_used` increments on each barcode lookup, OCR operation, or Gemini AI food scan.
- `usage_counters` resets on a scheduled Postgres cron job (`pg_cron`) or a scheduled Edge Function at the start of each billing period.
- Stripe webhook (`checkout.session.completed`, `customer.subscription.updated/deleted`) hits an Edge Function that upserts `subscriptions` — this is the single source of truth the app reads to gate features.

---

## 8. Onboarding Flow

```
App launch
   │
   ▼
Fetch profiles.login_count
   │
   ├── 0  → show onboarding carousel (feature highlights)
   │         → end screen: paywall/upsell (Skip or Subscribe)
   │         → set has_completed_onboarding = true, increment login_count
   │
   └── >0 → go straight to pantry_list_screen, increment login_count
```

Increment `login_count` via an Edge Function called once per app session start (not per screen), so it's a true "sessions" counter, not accidentally incremented on hot reload/navigation.

---

## 9. Suggested Build Order

1. Supabase schema + RLS policies + auth
2. Flutter shell: routing, theme, Riverpod wiring, onboarding flow
3. Pantry CRUD + manual entry (get the core loop working before adding AI)
4. Barcode scanning + Open Food Facts lookup
5. Expiry heuristic table + label OCR fallback
6. **Gemini AI service + AI food item scanning with editable manual expiry review**
7. Recipe generation Edge Function + cache table (single-item first)
8. Expiring-soon recipe variant
9. Favorites (JSON snapshot)
10. Shopping list + export (CSV/PDF share sheet)
11. Subscription tiers, quota enforcement, Stripe integration
12. Performance pass: profiling with Flutter DevTools, list virtualization checks, isolate audit

---

## 10. Packages to Use

```yaml
dependencies:
  flutter_riverpod:
  riverpod_annotation:
  go_router:
  supabase_flutter:
  freezed_annotation:
  json_annotation:
  mobile_scanner:                 # barcode
  google_mlkit_text_recognition:  # label OCR
  image_picker:                   # camera photo capture & gallery selection for AI scanning
  cached_network_image:
  flutter_image_compress:         # compress photos before sending to Gemini / storage
  share_plus:                     # shopping list export
  csv:                            # shopping list export format

dev_dependencies:
  build_runner:
  freezed:
  json_serializable:
  riverpod_generator:
```
