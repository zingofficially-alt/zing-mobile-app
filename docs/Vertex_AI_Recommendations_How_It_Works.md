# Vertex AI Recommendations in ZING: How It Works

This document explains how recommendations work in this app from end to end, with a focus on learning the runtime flow.

## 1) High-level architecture

The recommendation stack has 4 layers:

1. Flutter UI widgets and screens request and display recommendations.
2. `RecommendationProvider` and `RecommendationService` manage state and Cloud Function calls.
3. Firebase Cloud Functions bridge Flutter to Vertex AI Retail API.
4. Vertex AI Retail stores catalog data, receives user events, and returns ranked prediction IDs.

## 2) Core files

- Flutter state layer:
  - `lib/Service/RecommendationProvider.dart`
  - `lib/Service/RecommendationService.dart`
- Flutter UI usage:
  - `lib/screen/HomeScreen.dart`
  - `lib/screen/StoreScreen/StoreScreen.dart`
  - `lib/Cart/CartScreen.dart`
  - `lib/screen/UserScreens/OrderHistoryPage.dart`
  - `lib/Widgets/Recommendations/RecommendedStoresRow.dart`
  - `lib/Widgets/Recommendations/RecommendedProductsRow.dart`
- Backend:
  - `functions/index.js`
- Operational scripts:
  - `functions/zing_setup.js`
  - `functions/seed_events.js`
  - `functions/zing_diag.js`

## 3) Placement IDs used by the app

These IDs are constants in `RecommendationProvider` and must match Retail serving config IDs:

- `home_recommended`
- `store_also_viewed`
- `cart_bought_together`
- `post_order_stores`

## 4) Catalog sync flow (Firestore -> Vertex AI Retail)

Before recommendations can work, Vertex AI needs a catalog.

### Real-time sync

Cloud Functions in `functions/index.js`:

- `onStoreWrite`: syncs/deletes `store_<storeId>`
- `onProductWrite`: syncs/deletes `product_<storeId>_<productId>`

### Scheduled sync

- `syncCatalog` runs daily at `02:00 UTC` and re-imports all stores and products.

### ID convention

- Store item ID in Retail: `store_<firestoreStoreId>`
- Product item ID in Retail: `product_<storeId>_<productId>`

This ID format is critical because prediction results come back as IDs and are resolved in Flutter using this pattern.

## 5) Recommendation request flow (screen load -> predictions)

### Step A: screen triggers fetch

Examples:

- Home: logs `home-page-view`, fetches `home_recommended`
- Store detail: logs `detail-page-view`, fetches `store_also_viewed` with product context IDs
- Cart: fetches `cart_bought_together` using cart item IDs
- Order history: fetches `post_order_stores`

### Step B: provider calls service

`RecommendationProvider.fetchRecommendations(...)`:

- sets loading state per placement
- calls `RecommendationService.getRecommendations(...)`
- stores:
  - result IDs (`_results[placement]`)
  - attribution token (`_attributionTokens[placement]`)

### Step C: service calls callable function

`RecommendationService.getRecommendations(...)` calls Firebase callable `getRecommendations` with:

- `placement`
- `userId` (nullable)
- `visitorId` (UID or `"anonymous"`)
- optional `productIds`
- optional `filter`

If call fails or times out, it returns empty results/token.

### Step D: Cloud Function calls Retail Predict API

`functions/index.js` -> `exports.getRecommendations`:

- builds placement path:
  - `projects/zing-262ad/locations/global/catalogs/default_catalog/servingConfigs/<placement>`
- calls `PredictionServiceClient.predict(...)`
- returns:
  - `results`: list of Retail IDs
  - `attributionToken`

If Retail predict fails, function returns empty results and empty token.

## 6) Rendering flow (prediction IDs -> visible cards)

The UI widgets do not render raw IDs. They resolve IDs to in-memory app models:

- `resolveStores(...)` maps `store_<id>` to `Store`
- `resolveProducts(...)` maps `product_<storeId>_<productId>` to `Product`

Then:

- `RecommendedStoresRow` renders store cards
- `RecommendedProductsRow` renders product cards

## 7) Event logging flow (user behavior -> model learning)

Recommendations improve only if user events are logged.

### Flutter side

`RecommendationProvider.logEvent(...)` sends events via `RecommendationService.logEvent(...)` -> callable `logUserEvent`.

Common event types used in app:

- `home-page-view`
- `detail-page-view`
- `purchase-complete`

### Backend side

`functions/index.js` -> `exports.logUserEvent`:

- converts `productIds` to `productDetails`
- writes event to Retail `UserEventService`
- for `purchase-complete`, adds `purchaseTransaction` with revenue and currency (`LKR`)

### Attribution token

If UI action comes from recommended content, token should be passed with event so Retail can learn attribution.

In this app:

- token is stored by placement in provider
- recommendation row widgets pass token when logging clicks from recommendation cards

## 8) Fallback behavior (important for UX)

The app avoids blank recommendation sections:

- Store fallback: sort stores by rating count (popularity)
- Product fallback: shuffle context products

Fallback is used when:

- API errors
- timeouts
- empty prediction results
- model cold start/training period

## 9) Cold start and training lifecycle

New projects often return empty recommendations initially.

Operational scripts:

- `zing_setup.js`: creates serving configs and attempts model creation
- `seed_events.js`: injects large synthetic event volume to satisfy training thresholds
- `zing_diag.js`: checks catalog, model state, serving configs, prediction health, and event writes

Typical timeline:

1. Sync catalog
2. Send enough events
3. Wait for event indexing (often 1-2 hours)
4. Train model (can take days)
5. Link serving configs to trained model

Until then, fallback logic is expected behavior.

## 10) Practical learning checklist

If you want to understand this system quickly, inspect in this order:

1. `RecommendationProvider.fetchRecommendations` and `logEvent`
2. `RecommendationService.getRecommendations` and `logEvent`
3. `functions/index.js` callable functions (`getRecommendations`, `logUserEvent`)
4. UI call sites in Home, Store, Cart, Order screens
5. `resolveStores`, `resolveProducts`, fallback methods

## 11) Sequence summary

```text
User opens screen
  -> Flutter screen calls fetchRecommendations(placement, contextIds)
  -> Provider calls Cloud Function getRecommendations
  -> Cloud Function calls Vertex AI Retail Predict
  -> Vertex returns ranked item IDs + attributionToken
  -> Provider stores IDs/token
  -> UI resolves IDs to app Store/Product models
  -> UI renders recommendation cards

User taps recommended item
  -> Flutter logs event with attributionToken
  -> Cloud Function writes user event to Retail
  -> Retail model gets better over time
```

## 12) Notes

- The system is intentionally resilient: errors degrade gracefully to fallback content.
- Recommendation quality depends heavily on event quality, ID consistency, and serving config/model setup.
- If you see empty recommendations with no crash, first verify model/serving config health using `zing_diag.js`.

