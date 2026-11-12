# ZING — AI Recommendations: Architecture & Google Cloud Setup Guide

**Project:** ZING Flutter + Firebase Marketplace
**Firebase Project ID:** `zing-262ad`
**Service Used:** Google Cloud Vertex AI Retail API (formerly Recommendations AI)
**Last Updated:** 2026-02-18

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [How the Recommendation System Works](#3-how-the-recommendation-system-works)
4. [Google Cloud Console Setup](#4-google-cloud-console-setup)
5. [Firebase Functions Setup](#5-firebase-functions-setup)
6. [Flutter Integration](#6-flutter-integration)
7. [Placement Reference](#7-placement-reference)
8. [Catalog ID Conventions](#8-catalog-id-conventions)
9. [User Events Reference](#9-user-events-reference)
10. [Fallback Behavior](#10-fallback-behavior)
11. [Cold Start — Seeding Events](#11-cold-start--seeding-events)
12. [Deployment Checklist](#12-deployment-checklist)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Overview

ZING uses the **Google Cloud Vertex AI Retail API** to power personalized recommendations for stores and products. The system:

- Maintains a **product catalog** in Vertex AI that mirrors Firestore data (stores + products).
- **Logs user behavior events** (page views, cart additions, purchases) to train the recommendation model.
- **Fetches real-time predictions** via the Predict API and displays them in the Flutter app.
- Gracefully falls back to popularity-sorted / shuffled results when the API is unavailable or has insufficient training data.

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│                                                                 │
│  RecommendationProvider  ──►  RecommendationService            │
│  (state + fallback logic)     (Cloud Functions client)         │
│                                                                 │
│  RecommendedStoresRow    RecommendedProductsRow                │
│  (UI widget)              (UI widget)                           │
└────────────┬───────────────────────────┬────────────────────────┘
             │ logUserEvent()            │ getRecommendations()
             ▼                           ▼
┌─────────────────────────────────────────────────────────────────┐
│               Firebase Cloud Functions (Node 18)                │
│                                                                 │
│  logUserEvent   getRecommendations   syncCatalog               │
│  onStoreWrite   onProductWrite                                  │
└──────────┬──────────────┬────────────────────────────┬──────────┘
           │              │                            │
           ▼              ▼                            ▼
┌──────────────────────────────────────────────────────────────┐
│              Google Cloud Vertex AI Retail API               │
│                                                              │
│   UserEventService   PredictionService   ProductService     │
│   (write events)     (get predictions)   (catalog CRUD)     │
└──────────────────────────────────────────────────────────────┘
           ▲
           │ (Firestore triggers)
┌──────────┴─────────────────┐
│        Cloud Firestore      │
│  /stores/{id}               │
│  /stores/{id}/products/{id} │
└─────────────────────────────┘
```

---

## 3. How the Recommendation System Works

### Step 1 — Catalog Sync
Store and product data from Firestore is synced into the Vertex AI Retail catalog. This happens in two ways:
- **Real-time**: Firestore triggers (`onStoreWrite`, `onProductWrite`) upsert or delete items immediately when documents change.
- **Scheduled**: `syncCatalog` runs daily at 02:00 UTC to do a full re-sync as a safety net.

### Step 2 — Event Logging
When users interact with the app, behavioral events are sent to the Vertex AI User Event Service:
- Viewing a store/product page → `detail-page-view`
- Adding to cart → `add-to-cart`
- Completing purchase → `purchase-complete`

These events train the ML model over time to understand user preferences.

### Step 3 — Fetching Predictions
When screens load, the app calls `getRecommendations` with a **placement ID** and optional context product IDs. The Vertex AI Predict API returns a ranked list of catalog item IDs.

### Step 4 — Rendering
Flutter resolves the returned catalog IDs back to local `Store` and `Product` objects and renders them in horizontal scrollable rows (`RecommendedStoresRow`, `RecommendedProductsRow`).

### Step 5 — Fallback
If the API returns empty results (e.g., cold start, insufficient data, network error), the app shows:
- **Stores**: sorted by number of ratings (most popular first)
- **Products**: shuffled from the current context

---

## 4. Google Cloud Console Setup

### 4.1 Enable the Retail API

**Direct link →** https://console.cloud.google.com/apis/library/retail.googleapis.com?project=zing-262ad

1. Click the link above — it opens the Retail API page for `zing-262ad`
2. Click **Enable**
3. Wait ~30 seconds for activation

### 4.2 Grant IAM Permissions to the Functions Service Account

**Direct link →** https://console.cloud.google.com/iam-admin/iam?project=zing-262ad

1. Find the App Engine default service account:
   ```
   zing-262ad@appspot.gserviceaccount.com
   ```
2. Click **Edit (pencil icon)** → **Add another role**
3. Search for and select: **`Retail Editor`** (`roles/retail.editor`)
4. Click **Save**

> **Tip:** If you also want the service account to view catalog analytics, also add `roles/retail.viewer`.

### 4.3 Accept Data Use Terms (Required for Event Logging)

**Direct link →** https://console.cloud.google.com/ai/retail?project=zing-262ad

1. Open the link above
2. Under **Data use terms**, click **Accept**

Without this, all `writeUserEvent` calls will fail silently.

### 4.4 Verify the Retail Catalog

**Direct link →** https://console.cloud.google.com/ai/retail/catalogs/default_catalog/branches/0/products?project=zing-262ad

The catalog is created automatically when the first product is imported via `syncCatalog`. After running the seed script (Section 11), you should see items here.

Catalog path used in code:
```
projects/zing-262ad/locations/global/catalogs/default_catalog
```

### 4.5 Create a Recommendation Model

**Direct link →** https://console.cloud.google.com/ai/retail/catalogs/default_catalog/models/?project=zing-262ad

1. Click **Create Model**
2. Fill in:
   - **Model name**: `zing-recommendations`
   - **Model type**: `Others You May Like`
   - **Objective**: `Click-Through Rate`
   - **Data filtering**: All catalog items
3. Click **Create**

> The model will show status **Training** for 2–8 hours. The app uses fallback logic automatically during this time.

**Data requirements before creating model** (must all be green):

| Requirement | Threshold |
|---|---|
| `detail-page-view` events | 10,000+ in last 90 days |
| Unique catalog items with events | 100+ |
| Days of event coverage | 7+ days OR 60+ days |

See **Section 11** for how to seed events to meet these requirements immediately.

### 4.6 Create Serving Configs (Placements)

**Direct link →** https://console.cloud.google.com/ai/retail/catalogs/default_catalog/configs/?project=zing-262ad

Create **4 serving configs** — one for each placement. Click **Create Serving Config** for each:

| # | Serving Config ID | Use Case | Recommendation Type |
|---|---|---|---|
| 1 | `home_recommended` | Home screen — personalized stores | Others You May Like |
| 2 | `store_also_viewed` | Store page — "Also Viewed" stores | Others You May Like |
| 3 | `cart_bought_together` | Cart — "Bought Together" products | Others You May Like |
| 4 | `post_order_stores` | Post-order — suggested stores | Others You May Like |

For each config:
1. **Config ID**: Use exactly the IDs above (case-sensitive, underscores)
2. **Model**: Link to `zing-recommendations` (once trained)
3. **Price reranking**: Disabled
4. **Diversity level**: Medium
5. Click **Create**

### 4.7 Monitor Cloud Function Logs

**Direct link →** https://console.cloud.google.com/logs/query?project=zing-262ad

Use this filter to see Retail-related function logs:
```
resource.type="cloud_function"
```

### 4.8 Check Retail API Quotas

**Direct link →** https://console.cloud.google.com/apis/api/retail.googleapis.com/quotas?project=zing-262ad

Check here if you see quota errors in function logs.

---

## 5. Firebase Functions Setup

### 5.1 Install Dependencies

```bash
cd functions
npm install
```

The key NPM package is:
```json
"@google-cloud/retail": "^4.x"
```

### 5.2 Configuration Constants

All Retail API constants are defined at the top of `functions/index.js`:

```javascript
const PROJECT_ID = "zing-262ad";
const LOCATION   = "global";           // Retail API is always "global"
const CATALOG    = "default_catalog";  // Do not change
const BRANCH     = "0";               // Branch 0 = default
```

### 5.3 Cloud Functions Summary

| Function | Trigger | Purpose |
|---|---|---|
| `syncCatalog` | Scheduled (daily 02:00 UTC) | Full Firestore → Retail catalog sync |
| `onStoreWrite` | Firestore trigger on `stores/{storeId}` | Real-time store upsert/delete |
| `onProductWrite` | Firestore trigger on `stores/{id}/products/{id}` | Real-time product upsert/delete |
| `logUserEvent` | HTTPS Callable | Write a user behavior event to Retail |
| `getRecommendations` | HTTPS Callable | Call Predict API, return ranked IDs |
| `deleteUser` | HTTPS Callable | Delete Firebase Auth user (unrelated) |

### 5.4 Deploy Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

To deploy a single function:
```bash
firebase deploy --only functions:syncCatalog
```

### 5.5 Trigger Initial Catalog Seed

After deploying for the first time, manually trigger `syncCatalog`:

```bash
firebase functions:call syncCatalog
```

Monitor the result at:
**→** https://console.cloud.google.com/logs/query?project=zing-262ad

---

## 6. Flutter Integration

### 6.1 Files

| File | Purpose |
|---|---|
| `lib/Service/RecommendationService.dart` | Low-level Cloud Functions caller |
| `lib/Service/RecommendationProvider.dart` | State management + fallback logic |
| `lib/Widgets/Recommendations/RecommendedStoresRow.dart` | Store recommendation UI widget |
| `lib/Widgets/Recommendations/RecommendedProductsRow.dart` | Product recommendation UI widget |

### 6.2 Register the Provider

In `main.dart` or your `MultiProvider` setup, register:

```dart
ChangeNotifierProvider(create: (_) => RecommendationProvider()),
```

### 6.3 Fetch Recommendations in a Screen

```dart
// In initState or didChangeDependencies:
final recProvider = Provider.of<RecommendationProvider>(context, listen: false);

// Home screen — recommended stores
recProvider.fetchRecommendations(
  placement: RecommendationProvider.homeRecommended,
);

// Store detail page — also viewed
recProvider.fetchRecommendations(
  placement: RecommendationProvider.storeAlsoViewed,
  productIds: ['store_${store.id}'],
);

// Cart page — bought together
recProvider.fetchRecommendations(
  placement: RecommendationProvider.cartBoughtTogether,
  productIds: cartItems.map((i) => 'product_${i.storeId}_${i.productId}').toList(),
);
```

### 6.4 Display the Widgets

```dart
// Recommended stores row
RecommendedStoresRow(
  placement: RecommendationProvider.homeRecommended,
  sectionTitle: 'Recommended for You',
  user: currentUser,
)

// Recommended products row
RecommendedProductsRow(
  placement: RecommendationProvider.cartBoughtTogether,
  sectionTitle: 'Frequently Bought Together',
  fallbackProducts: currentStoreProducts,
)
```

### 6.5 Log User Events

```dart
final recProvider = Provider.of<RecommendationProvider>(context, listen: false);

// When a user views a store
recProvider.logEvent(
  eventType: 'detail-page-view',
  productIds: ['store_${store.id}'],
  attributionToken: recProvider.getToken(RecommendationProvider.homeRecommended),
);

// When a user adds to cart
recProvider.logEvent(
  eventType: 'add-to-cart',
  productIds: ['product_${storeId}_${product.id}'],
);

// When a purchase completes
recProvider.logEvent(
  eventType: 'purchase-complete',
  productIds: orderItems.map((i) => 'product_${i.storeId}_${i.id}').toList(),
  purchaseAmount: totalAmount,
  transactionId: orderId,
);
```

> Always pass `attributionToken` when logging events after a recommendation was shown. This allows Vertex AI to attribute the click back to the recommendation, improving model quality.

---

## 7. Placement Reference

| Constant | Serving Config ID | Screen | Context Passed |
|---|---|---|---|
| `RecommendationProvider.homeRecommended` | `home_recommended` | Home screen | None |
| `RecommendationProvider.storeAlsoViewed` | `store_also_viewed` | Store detail page | `['store_<id>']` |
| `RecommendationProvider.cartBoughtTogether` | `cart_bought_together` | Cart screen | All cart item IDs |
| `RecommendationProvider.postOrderStores` | `post_order_stores` | Order confirmation | None |

---

## 8. Catalog ID Conventions

The Retail API requires globally unique string IDs per catalog item. ZING uses this convention:

| Entity | Catalog ID Format | Example |
|---|---|---|
| Store | `store_<firestoreDocId>` | `store_abc123` |
| Product | `product_<storeId>_<productId>` | `product_abc123_xyz789` |

These IDs are used:
- When importing products into the catalog (`storeToRetailProduct`, `productToRetailProduct`)
- In `productIds` arrays sent with user events and prediction requests
- When resolving returned prediction IDs back to Flutter objects (`resolveStores`, `resolveProducts`)

---

## 9. User Events Reference

Events logged via `logUserEvent` Cloud Function:

| Event Type | When to Log | Required Fields |
|---|---|---|
| `detail-page-view` | User opens a store or product page | `productIds`, `visitorId` |
| `add-to-cart` | User adds item to cart | `productIds`, `visitorId` |
| `purchase-complete` | Order confirmed | `productIds`, `purchaseAmount`, `transactionId` |
| `search` | User performs a search | `visitorId` |

The `visitorId` is automatically set to the Firebase Auth UID (or `"anonymous"` for unauthenticated users).

---

## 10. Fallback Behavior

The system is designed to never show an empty section to the user.

| Condition | Store Fallback | Product Fallback |
|---|---|---|
| API returns empty results | Top stores by ratings count (descending) | Context products shuffled randomly |
| API timeout (>10 seconds) | Same as above | Same as above |
| Network error | Same as above | Same as above |
| Model still training | Same as above | Same as above |

If even the fallback list is empty (e.g., no stores loaded yet), the widget returns `SizedBox.shrink()` and shows nothing.

---

## 11. Cold Start — Seeding Events

Before training a model, Google requires minimum event thresholds. If starting from zero, use the provided seed script to inject synthetic historical events.

### Requirements to unlock model training

| Requirement | Threshold | How seed_events.js satisfies it |
|---|---|---|
| `detail-page-view` events | 10,000+ | Generates 12,000 |
| Unique catalog items with events | 100+ | Uses real Firestore IDs (or 250 synthetic) |
| Days of event coverage | 7+ days | Spreads events across 88 days |

### Step 1 — Authenticate with Google Cloud

```bash
gcloud auth application-default login
```

This opens a browser for login. Sign in with the account that owns `zing-262ad`.

### Step 2 — Sync the Catalog First

```bash
firebase functions:call syncCatalog
```

Wait ~2 minutes. Verify items appeared:
**→** https://console.cloud.google.com/ai/retail/catalogs/default_catalog/branches/0/products?project=zing-262ad

### Step 3 — Run the Seed Script

```bash
cd /path/to/ZING/functions
node seed_events.js
```

Expected output:
```
============================================================
ZING — Vertex AI Retail Event Seeder
============================================================
Fetching stores from Firestore...
Found X stores, Y products in Firestore.
Generating 12,000 detail-page-view events...
Generating 12,000 home-page-view events...
Generating 1,800 add-to-cart events...
Total events generated: 25,800
Importing in batches of 5,000...
  Batch 1: submitted 5000 events, operation: projects/...
  Batch 2: submitted 5000 events, operation: projects/...
  ...
Done. 6/6 batches submitted successfully.
```

### Step 4 — Wait 1–2 Hours, Then Create Model

After seeding, Google takes 1–2 hours to process events. Then check:
**→** https://console.cloud.google.com/ai/retail/catalogs/default_catalog/models/?project=zing-262ad

All three requirements should show green checkmarks. Click **Create Model**.

---

## 12. Deployment Checklist

Use this checklist when setting up the system from scratch or after a major change.

### Google Cloud Console

| # | Task | Link |
|---|---|---|
| 1 | Enable Retail API | https://console.cloud.google.com/apis/library/retail.googleapis.com?project=zing-262ad |
| 2 | Grant `roles/retail.editor` to service account | https://console.cloud.google.com/iam-admin/iam?project=zing-262ad |
| 3 | Accept Data Use Terms | https://console.cloud.google.com/ai/retail?project=zing-262ad |
| 4 | Seed events (Section 11) then create model `zing-recommendations` | https://console.cloud.google.com/ai/retail/catalogs/default_catalog/models/?project=zing-262ad |
| 5 | Create 4 serving configs | https://console.cloud.google.com/ai/retail/catalogs/default_catalog/configs/?project=zing-262ad |
| 6 | Link trained model to each serving config | https://console.cloud.google.com/ai/retail/catalogs/default_catalog/configs/?project=zing-262ad |
| 7 | Verify catalog items | https://console.cloud.google.com/ai/retail/catalogs/default_catalog/branches/0/products?project=zing-262ad |

### Firebase / Functions
- [ ] `@google-cloud/retail` package in `functions/package.json`
- [ ] `npm install` run in `functions/`
- [ ] All functions deployed: `firebase deploy --only functions`
- [ ] `syncCatalog` triggered manually once to seed the catalog
- [ ] `seed_events.js` run to satisfy model training data requirements
- [ ] Verified in Cloud Logs that catalog items were imported (no errors): https://console.cloud.google.com/logs/query?project=zing-262ad

### Flutter App
- [ ] `RecommendationProvider` registered in `MultiProvider`
- [ ] `fetchRecommendations` called on relevant screen init
- [ ] UI widgets added to screens
- [ ] Event logging calls added at key user actions (view, add-to-cart, purchase)

---

## 13. Troubleshooting

### "results: []" always returned

**Cause 1 — Model still training:**
Check model status → https://console.cloud.google.com/ai/retail/catalogs/default_catalog/models/?project=zing-262ad
If it shows "Training", wait 2–8 hours.

**Cause 2 — Serving config not linked to model:**
Go to → https://console.cloud.google.com/ai/retail/catalogs/default_catalog/configs/?project=zing-262ad
Select each config → Edit → ensure a trained model is selected.

**Cause 3 — Catalog is empty:**
Check → https://console.cloud.google.com/ai/retail/catalogs/default_catalog/branches/0/products?project=zing-262ad
If empty, run `firebase functions:call syncCatalog`.

**Cause 4 — Insufficient event data:**
Run `seed_events.js` as described in Section 11.

---

### "PERMISSION_DENIED" in Function Logs

The service account is missing the Retail Editor role.
Fix → https://console.cloud.google.com/iam-admin/iam?project=zing-262ad
Add role `roles/retail.editor` to `zing-262ad@appspot.gserviceaccount.com`.

---

### "NOT_FOUND" for serving config

The serving config ID in the code does not match what was created in the console. The IDs are **case-sensitive**.

Verify configs exist → https://console.cloud.google.com/ai/retail/catalogs/default_catalog/configs/?project=zing-262ad

Required IDs:
- `home_recommended`
- `store_also_viewed`
- `cart_bought_together`
- `post_order_stores`

---

### Products not appearing in catalog

Check logs → https://console.cloud.google.com/logs/query?project=zing-262ad

Filter: `resource.type="cloud_function" jsonPayload.message=~"syncCatalog"`

Common causes:
- Firestore document fields missing (e.g., `name` is null)
- `imageUrl` is empty (allowed — image is optional)
- Retail API quota exceeded → https://console.cloud.google.com/apis/api/retail.googleapis.com/quotas?project=zing-262ad

---

### Slow recommendation load / timeout

The `getRecommendations` function has a **10-second timeout** on the Flutter side. If predictions consistently time out:
1. Check Cloud Function region — ensure functions are deployed to a region close to your users (default is us-central1).
2. Check Vertex AI Retail API latency → https://console.cloud.google.com/monitoring?project=zing-262ad
3. Consider increasing the timeout in `RecommendationService.dart` if needed.

---

*Document generated for the ZING project. Firebase Project: `zing-262ad`. Stack: Flutter + Firebase + Vertex AI Retail API.*
