# Pantry Tracker — Project Summary & Build Timeline

This is a consolidated log of everything decided and built so far, in the
order it happened, plus the recommended build order going forward. Meant as
a single reference for anyone (or any tool) picking this project up.

**Stack:** Flutter (Riverpod) · Supabase (Postgres, Auth, Storage, Edge
Functions) · Google Gemini (recipe generation) · RevenueCat (subscriptions,
via App Store / Play Store billing)

---

## 1. Original Feature Spec

- Scan food items in, predict expiry (editable manually)
- Barcode scanning
- Recipe generation per pantry item — pantry-aware first, falls back to a
  solo recipe using just that item
- Recipe generation for items about to expire
- Shopping list with export
- Subscription tiers: free (3 scans/month, single-item scanning only) up to
  a top tier with the most recipe generations/month
- Favorite recipes, saved as JSON
- A shared, deduplicated recipe database — the AI-generation step is meant
  to be replaceable later with an in-house algorithm once this fills up
- Onboarding gated on login count, ending in a skippable premium upsell
- Priorities: no laggy frontend, deployable-grade quality

## 2. Early Decisions (asked and answered)

| Decision | Choice |
|---|---|
| State management | Riverpod |
| Recipe generation LLM | Google Gemini (free tier) |
| Subscription billing | Stripe → **later changed to RevenueCat** (see Section 5) |

## 3. Architecture Document

Full system design written first: `pantry_tracker_architecture.md`. Covers:

- Feature-first Flutter project structure under `lib/`
- Full Supabase Postgres schema (`profiles`, `subscriptions`,
  `usage_counters`, `pantry_items`, `recipes`, `favorite_recipes`,
  `shopping_list_items`) with RLS policies
- The recipe cache/dedup strategy: `recipes` is a **shared, global** table
  (not per-user), deduplicated by `normalized_name + primary_ingredient`,
  with a `generation_count` popularity signal — this is the table meant to
  eventually replace Gemini calls with an in-house lookup
- Performance rules: isolates for OCR/barcode decode, paginated pantry
  lists, `select()`-scoped Riverpod watches, on-device image compression
- Barcode scanning via `mobile_scanner` + Open Food Facts API; expiry
  prediction via on-device label OCR with a category-based heuristic
  fallback
- Suggested 11-step build order (superseded by Section 6 below, now that
  billing strategy has changed)

## 4. App Naming

Discussed several directions (functional, playful, waste-reduction-angle,
premium/minimal). Top picks: **BestBy** (short, names the core problem
directly) and **Pantrly** (brandable invented word, easy domain/trademark).
No final decision recorded — revisit before any store listing work.

## 5. Edge Functions — Built

All in `supabase/functions/`, with shared helpers in `_shared/`:

| Function | Purpose |
|---|---|
| `generate-recipe` | Cache-first, pantry-aware recipe for a tapped item; quota-checked before calling Gemini |
| `generate-expiring-recipes` | Same pipeline for items expiring soon, cached by ingredient-set signature |
| `barcode-lookup` | Open Food Facts lookup, cached in `barcode_cache` |
| `increment-login` | Session counter driving the onboarding gate |
| `create-checkout-session` / `stripe-webhook` | **Originally built for Stripe. Now web-only/optional — see Section 5a.** |
| `reset-usage-counters` | Scheduled monthly quota reset |
| `revenuecat-webhook` | **Added after the billing pivot** — see Section 6 |

Shared helpers: `_shared/cors.ts`, `_shared/supabaseAdmin.ts`,
`_shared/tierLimits.ts`, `_shared/gemini.ts`, `_shared/quota.ts`.

Migration `0002_edge_function_support.sql` adds `ingredient_signature`,
`barcode_cache`, and `stripe_customer_id` on top of the base schema.

### 5a. The Stripe → RevenueCat Pivot

Stripe was the original choice, and `create-checkout-session` +
`stripe-webhook` were fully built for it, including:
- Full Stripe setup walkthrough (account, API keys, products/prices,
  webhook registration, test-mode checkout with `4242 4242 4242 4242`, going
  live)
- A note, given up front, that **Apple and Google generally require
  in-app digital subscriptions to go through their own billing** (StoreKit /
  Play Billing), not a card processor called from inside the app — flagged
  as a compliance risk before those functions were even written

That risk became the reason for the pivot: once the goal was explicitly
"Apple and Android approved payment setup," Stripe's in-app checkout path
was replaced with native store billing via **RevenueCat**. The
`subscriptions` table was deliberately designed provider-agnostic from the
start (`provider: 'stripe' | 'apple' | 'google'`), so this pivot required
**zero schema changes** — only a new webhook function and new Flutter
purchase code.

`create-checkout-session` / `stripe-webhook` remain in the repo, unused by
the mobile app, in case a future web version wants Stripe checkout.

## 6. RevenueCat Integration — Built

Full reference doc: `docs/revenuecat_integration.md` (point any other
tool/agent at this file first — it has a live "not yet done" checklist).

**Backend:**
- `revenuecat-webhook/index.ts` — receives RevenueCat events, upserts
  `subscriptions`. Key logic: `CANCELLATION` sets status only (access
  continues until period end); `EXPIRATION` is the actual tier downgrade to
  `free`; `BILLING_ISSUE` sets `past_due` during the store's grace period.
- `supabase/config.toml` updated to exempt `revenuecat-webhook` from
  default JWT verification (it authenticates via a shared secret header
  instead).

**Flutter (`lib/`):**
- `core/services/purchases_service.dart` — the only file that imports
  `purchases_flutter` directly
- `core/constants/subscription_constants.dart` — entitlement ID constants
  + `SubscriptionTier` enum
- `data/repositories/subscription_repository.dart` — read-only access to
  the backend `subscriptions` row (webhooks are the only writer)
- `features/subscription/application/subscription_controller.dart` —
  Riverpod controller merging RevenueCat's instant local entitlement state
  with the backend row as source of truth
- `features/subscription/presentation/screens/paywall_screen.dart` — the
  paywall UI, reused for both the onboarding upsell and any
  quota-exceeded prompt

**RevenueCat dashboard setup walkthrough covered:**
1. Create Plus/Pro subscription products in App Store Connect and Play
   Console first (RevenueCat wraps existing products, doesn't create them)
2. Create a RevenueCat project
3. Connect the iOS app (Bundle ID + App-Specific Shared Secret)
4. Connect the Android app (package name + Service Account JSON — note:
   Play Console API access can take hours to propagate)
5. Import store products into RevenueCat
6. Create Entitlements (`plus_access`, `pro_access` or similar) and attach
   products to each
7. Create an Offering with Packages — this is what the Flutter paywall
   fetches via `getCurrentOffering()`
8. Grab the public API keys (per platform — safe to embed client-side,
   distinct from the secret admin key)

Remaining before this is live: run `build_runner` to generate
`subscription_controller.g.dart`, fill in real entitlement identifiers and
API keys, wire `PurchasesService.configure()` into app startup post-login,
insert `PaywallScreen` into the onboarding flow, and connect
`quota_exceeded` responses to trigger the paywall.

---

## 7. Recommended Build Order (current, supersedes Section 3's original list)

The question that prompted this doc: **should the app be functional before
implementing RevenueCat?** Yes — billing goes last, not first. Reasoning:
RevenueCat needs real store products, which need a near-final bundle ID and
build; every core feature works identically regardless of tier since
`checkRecipeQuota` already defaults an unrecognized user to `free`; and
debugging is easier when app logic and billing logic aren't tangled
together while both are still unstable.

```
1. Supabase schema + RLS policies + auth
2. Flutter shell: routing, theme, Riverpod wiring, onboarding flow
   (paywall screen can be stubbed/placeholder here — see step 9)
3. Pantry CRUD + manual entry
4. Barcode scanning + Open Food Facts lookup
5. Expiry heuristic table + label OCR fallback
6. Recipe generation Edge Function + cache table (single-item first)
7. Expiring-soon recipe variant
8. Favorites (JSON snapshot) + shopping list + export
   — at this point the app is fully functional on the free tier,
     with subscriptions table empty and everyone defaulting to 'free'
9. Once near a real build/bundle ID: create store subscription products,
   set up RevenueCat (Section 6's 8 steps), wire PurchasesService +
   PaywallScreen into the already-stubbed onboarding/upsell UI
10. Deploy revenuecat-webhook, set its env vars, test with sandbox accounts
11. Performance pass: DevTools profiling, list virtualization checks,
    isolate audit
```

## 8. Open Items / Not Yet Decided

- Final app name (BestBy vs. Pantrly vs. other)
- Whether to keep the Stripe functions for a future web build, or remove
  them entirely
- RevenueCat entitlement identifiers and real API keys (placeholders only
  so far)
- Exact free/plus/pro quota numbers — current placeholders in
  `_shared/tierLimits.ts` are illustrative, not finalized
