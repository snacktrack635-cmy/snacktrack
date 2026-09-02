# RevenueCat Integration Reference

This doc describes the App Store / Play Store subscription integration for the
pantry tracker app, built via RevenueCat. It supersedes the Stripe-based
billing flow for mobile — Stripe's `create-checkout-session` and
`stripe-webhook` functions still exist in the repo but should be treated as
**web-only / optional**, not the mobile purchase path.

Read this alongside `pantry_tracker_architecture.md` (overall system design)
and `supabase/functions/README.md` (env vars + deploy commands for every
function). This file exists so an agent picking up the work later has full
context without re-deriving decisions already made.

---

## 1. Why RevenueCat, not Stripe, for mobile

Apple and Google require in-app digital subscriptions to go through
StoreKit / Play Billing, not a card processor called from inside the app.
RevenueCat sits on top of both platforms' native billing APIs and gives:

- One Flutter SDK (`purchases_flutter`) instead of integrating StoreKit and
  Play Billing separately
- Server-side receipt validation handled for you
- One webhook format covering both stores, instead of two
- A `subscriptions` table design that was already provider-agnostic
  (`provider: 'stripe' | 'apple' | 'google'`), so no schema migration was
  needed to add this

## 2. What already exists in the codebase

### Backend (Supabase)

| File | Status | Purpose |
|---|---|---|
| `supabase/functions/revenuecat-webhook/index.ts` | ✅ built | Receives RevenueCat events, upserts `public.subscriptions` |
| `supabase/config.toml` | ✅ updated | `revenuecat-webhook` added to the `verify_jwt = false` list |
| `supabase/functions/README.md` | ✅ updated | New env vars documented |
| `public.subscriptions` table | ✅ no change needed | Already had `provider`/`provider_subscription_id`/`status`/`current_period_end` columns from the original schema |

### Flutter (`lib/`)

| File | Status | Purpose |
|---|---|---|
| `core/services/purchases_service.dart` | ✅ built | Thin wrapper around `purchases_flutter` — the only file that imports the SDK directly |
| `core/constants/subscription_constants.dart` | ✅ built | Entitlement ID constants + `SubscriptionTier` enum |
| `data/repositories/subscription_repository.dart` | ✅ built | Reads the `subscriptions` table (read-only; webhooks are the only writer) |
| `features/subscription/application/subscription_controller.dart` | ✅ built | Riverpod controller merging instant local entitlement state with the backend row |
| `features/subscription/presentation/screens/paywall_screen.dart` | ✅ built | Paywall UI — used at end of onboarding and for quota-exceeded upsells |

### Not yet done — pick up here

- [ ] Run `flutter pub add purchases_flutter riverpod_annotation` (and confirm `riverpod_generator`/`build_runner` are already in `dev_dependencies` per the main architecture doc)
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` to generate `subscription_controller.g.dart` (referenced via `part` but not yet generated)
- [ ] Wire `PurchasesService.instance.configure(...)` into app startup, **after** the Supabase auth session is available (needs the user's id as `appUserId`) — see Section 4
- [ ] Create the actual products/entitlements/offering in the RevenueCat dashboard (see Section 3) and fill in the real entitlement identifiers + API keys wherever this doc says `TODO`
- [ ] Insert `PaywallScreen` at the end of the onboarding flow (`features/onboarding/`), with `canSkip: true`, per the original spec ("prompted to sign up to premium, can choose to skip")
- [ ] Wire quota-exceeded responses from `generate-recipe` / `generate-expiring-recipes` (`error: "quota_exceeded"`) to push `PaywallScreen` with `canSkip: true`
- [ ] Deploy `revenuecat-webhook` and set its env vars (Section 5)
- [ ] Decide whether to delete `create-checkout-session` / `stripe-webhook` entirely, or keep them dormant for a possible future web build

---

## 3. RevenueCat Dashboard Setup (manual, one-time)

1. Create subscription products in **App Store Connect** and **Google Play
   Console** for the Plus and Pro tiers (auto-renewing monthly, and
   optionally annual).
2. Create a RevenueCat project, add both apps (iOS + Android) under it.
3. Create two **Entitlements**: one for Plus, one for Pro. Attach the
   matching store products to each.
   - Update `REVENUECAT_ENTITLEMENT_PLUS` / `REVENUECAT_ENTITLEMENT_PRO`
     (backend env vars) to the exact identifiers chosen here.
   - Update `RevenueCatEntitlements.plus` / `.pro` in
     `core/constants/subscription_constants.dart` to match.
4. Create an **Offering** with **Packages** wrapping those products — this
   is what `PaywallScreen` renders via `getCurrentOffering()`.
5. Grab the iOS and Android **public SDK keys** (Project Settings → API
   keys) — these go wherever `PurchasesService.instance.configure()` is
   called (Section 4), not as Supabase secrets (they're safe to embed
   client-side; RevenueCat's public keys are scoped for this).

---

## 4. Flutter Wiring Still Needed

`PurchasesService.instance.configure()` must be called once per app
session, after the user is authenticated with Supabase (so their user id is
available), and before the paywall or any entitlement check runs. Suggested
spot: in the router's redirect/auth-state listener, right after a successful
sign-in, e.g.:

```dart
final userId = Supabase.instance.client.auth.currentUser!.id;
await PurchasesService.instance.configure(
  appUserId: userId,
  iosApiKey: const String.fromEnvironment('REVENUECAT_IOS_KEY'), // or a constants file — do not hardcode in source control
  androidApiKey: const String.fromEnvironment('REVENUECAT_ANDROID_KEY'),
);
```

Passing keys via `--dart-define` (and `--dart-define-from-file` for CI) is
the simplest way to keep them out of source control while still being
public-safe keys.

`SubscriptionController` (in `subscription_controller.dart`) is what the
rest of the app should watch to gate features — e.g. disabling batch
scanning UI when `tier == SubscriptionTier.free`. It already listens for
RevenueCat's local `CustomerInfo` changes for instant unlock, and exposes
`.refresh()` to pull the backend row directly (call this after returning
from `PaywallScreen`, which the screen already does internally).

**Client-side tier checks are UX only.** The real enforcement lives in the
`checkRecipeQuota` Edge Function helper, which reads the same
`subscriptions` table server-side. Don't skip that when adding new
tier-gated features — client state can be stale or tampered with.

---

## 5. Backend Env Vars for `revenuecat-webhook`

Set via `supabase secrets set` (see `supabase/functions/README.md` for the
full list including unrelated functions):

```
REVENUECAT_WEBHOOK_SECRET=<random-secret-you-generate>
REVENUECAT_ENTITLEMENT_PLUS=<entitlement id from Section 3, step 3>
REVENUECAT_ENTITLEMENT_PRO=<entitlement id from Section 3, step 3>
```

In the RevenueCat dashboard, under **Project Settings → Integrations →
Webhooks**, set:
- **URL**: `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook`
- **Authorization header value**: the literal string `Bearer <same value as REVENUECAT_WEBHOOK_SECRET>`
- **Events**: at minimum `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`,
  `EXPIRATION`, `PRODUCT_CHANGE`, `BILLING_ISSUE`, `UNCANCELLATION`

Deploy with:
```bash
supabase functions deploy revenuecat-webhook
```

---

## 6. Event Handling Logic (already implemented)

`revenuecat-webhook/index.ts` maps RevenueCat event types to `subscriptions`
table writes:

| Event | Effect |
|---|---|
| `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE`, `UNCANCELLATION`, `NON_RENEWING_PURCHASE` | Sets `tier` from the highest active entitlement, `status = 'active'`, updates `current_period_end` |
| `CANCELLATION` | Sets `status = 'canceled'` only — **tier is not downgraded**, since access continues until the period actually ends |
| `BILLING_ISSUE` | Sets `status = 'past_due'` — tier stays active during the store's grace period |
| `EXPIRATION` | Sets `tier = 'free'`, `status = 'expired'` — this is the actual downgrade point |

`app_user_id` on every event is expected to equal the Supabase `user_id`,
which only holds true if `PurchasesService.configure()` is called with
`appUserId: <supabase user id>` (Section 4) — don't let RevenueCat generate
its own anonymous ID here, or the webhook won't know which user to update.

## 7. Testing

- Use **Sandbox Testers** (App Store Connect) and a **licensed tester
  account on an internal testing track** (Play Console) — sandbox purchases
  exercise the real flow (including fast-forwarded renewals) without real
  charges.
- After a sandbox purchase, check RevenueCat's dashboard event log to
  confirm the webhook fired, then check the `subscriptions` row in Supabase
  directly to confirm the tier updated.
- Test the `CANCELLATION` → `EXPIRATION` sequence explicitly (cancel a
  sandbox subscription, then wait for its fast sandbox expiry) to confirm
  the tier only actually downgrades at `EXPIRATION`, not at `CANCELLATION`.
