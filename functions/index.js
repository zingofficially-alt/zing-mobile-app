const admin = require("firebase-admin");

// firebase-functions v2 API imports
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

admin.initializeApp();

const PROJECT_ID = "zing-262ad";
const LOCATION = "global";
const CATALOG = "default_catalog";
const BRANCH = "0";
const PARENT = `projects/${PROJECT_ID}/locations/${LOCATION}/catalogs/${CATALOG}`;
const BRANCH_PARENT = `${PARENT}/branches/${BRANCH}`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getProductClient() {
  const {ProductServiceClient} = require("@google-cloud/retail").v2;
  return new ProductServiceClient();
}

function getEventClient() {
  const {UserEventServiceClient} = require("@google-cloud/retail").v2;
  return new UserEventServiceClient();
}

function getPredictionClient() {
  const {PredictionServiceClient} = require("@google-cloud/retail").v2;
  return new PredictionServiceClient();
}

/**
 * Build a Retail v2 Product object from a Firestore store document.
 */
function storeToRetailProduct(storeId, store) {
  return {
    id: `store_${storeId}`,
    type: "PRIMARY",
    title: store.name || "Unnamed Store",
    description: store.description || "",
    tags: ["store", store.category || ""].filter(Boolean),
    priceInfo: {price: 0, originalPrice: 0, currencyCode: "LKR"},
    availability: "IN_STOCK",
    images: store.imageUrl
      ? [{uri: store.imageUrl, width: 256, height: 256}]
      : [],
  };
}

/**
 * Build a Retail v2 Product object from a Firestore product document.
 */
function productToRetailProduct(storeId, productId, product) {
  return {
    id: `product_${storeId}_${productId}`,
    type: "PRIMARY",
    title: product.name || "Unnamed Product",
    description: product.description || "",
    tags: ["product"],
    priceInfo: {
      price: product.price || 0,
      originalPrice: product.price || 0,
      currencyCode: "LKR",
    },
    availability: product.isAvailable !== false ? "IN_STOCK" : "OUT_OF_STOCK",
    images: product.imageUrl
      ? [{uri: product.imageUrl, width: 256, height: 256}]
      : [],
  };
}

/**
 * Upsert a single product into the Retail catalog (INCREMENTAL import).
 */
async function upsertRetailProduct(retailProduct) {
  const client = getProductClient();
  await client.importProducts({
    parent: BRANCH_PARENT,
    reconciliationMode: "INCREMENTAL",
    inputConfig: {
      productInlineSource: {products: [retailProduct]},
    },
  });
}

/**
 * Delete a product from the Retail catalog; ignores NOT_FOUND errors.
 */
async function deleteRetailProduct(retailId) {
  try {
    const client = getProductClient();
    await client.deleteProduct({
      name: `${BRANCH_PARENT}/products/${retailId}`,
    });
  } catch (err) {
    if (!err.message || !err.message.includes("NOT_FOUND")) {
      throw err;
    }
  }
}

// ---------------------------------------------------------------------------
// deleteUser — existing function (migrated to v2 onCall)
// ---------------------------------------------------------------------------

exports.deleteUser = onCall(async (request) => {
  // Only signed-in callers may use this function.
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const uid = request.data && request.data.uid;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new HttpsError("invalid-argument", "A valid uid is required.");
  }

  // A user may delete their own account; anyone else's needs an Admin.
  const callerUid = request.auth.uid;
  if (callerUid !== uid) {
    const callerDoc = await admin.firestore()
        .collection("users").doc(callerUid).get();
    const callerRole = callerDoc.exists ? callerDoc.get("role") : null;
    if (callerRole !== "Admin") {
      logger.warn("deleteUser: denied", {callerUid, targetUid: uid});
      throw new HttpsError("permission-denied",
          "Only an admin can delete other accounts.");
    }
  }

  try {
    await admin.auth().deleteUser(uid);
    logger.info("deleteUser: deleted", {callerUid, targetUid: uid});
    return {message: "User deleted successfully"};
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "User not found");
    }
    logger.error("deleteUser: failed", {callerUid, targetUid: uid, error});
    throw new HttpsError("internal", "Could not delete user.");
  }
});

// ---------------------------------------------------------------------------
// syncCatalog — scheduled daily at 02:00 UTC
// ---------------------------------------------------------------------------

exports.syncCatalog = onSchedule(
    {schedule: "0 2 * * *", timeZone: "UTC"},
    async () => {
      logger.info("syncCatalog: starting full catalog sync");
      const db = admin.firestore();
      const storesSnap = await db.collection("stores").get();

      for (const storeDoc of storesSnap.docs) {
        const storeId = storeDoc.id;
        const store = storeDoc.data();

        try {
          await upsertRetailProduct(storeToRetailProduct(storeId, store));
          logger.info(`syncCatalog: synced store ${storeId}`);
        } catch (err) {
          logger.error(`syncCatalog: failed store ${storeId}`, err);
        }

        // Sync this store's products
        const productsSnap = await storeDoc.ref.collection("products").get();
        for (const productDoc of productsSnap.docs) {
          const productId = productDoc.id;
          try {
            await upsertRetailProduct(
                productToRetailProduct(storeId, productId, productDoc.data()));
          } catch (err) {
            logger.error(
                `syncCatalog: failed product ${storeId}/${productId}`, err);
          }
        }
      }

      logger.info("syncCatalog: finished");
    },
);

// ---------------------------------------------------------------------------
// onStoreWrite — real-time store catalog sync
// ---------------------------------------------------------------------------

exports.onStoreWrite = onDocumentWritten("stores/{storeId}", async (event) => {
  const storeId = event.params.storeId;

  if (!event.data.after.exists) {
    try {
      await deleteRetailProduct(`store_${storeId}`);
      logger.info(`onStoreWrite: deleted store ${storeId}`);
    } catch (err) {
      logger.error(`onStoreWrite: failed to delete store ${storeId}`, err);
    }
    return;
  }

  const store = event.data.after.data();
  try {
    await upsertRetailProduct(storeToRetailProduct(storeId, store));
    logger.info(`onStoreWrite: upserted store ${storeId}`);
  } catch (err) {
    logger.error(`onStoreWrite: failed to upsert store ${storeId}`, err);
  }
});

// ---------------------------------------------------------------------------
// onProductWrite — real-time product catalog sync
// ---------------------------------------------------------------------------

exports.onProductWrite = onDocumentWritten(
    "stores/{storeId}/products/{productId}",
    async (event) => {
      const {storeId, productId} = event.params;

      if (!event.data.after.exists) {
        try {
          await deleteRetailProduct(`product_${storeId}_${productId}`);
          logger.info(
              `onProductWrite: deleted product ${storeId}/${productId}`);
        } catch (err) {
          logger.error(
              `onProductWrite: failed to delete product ${storeId}/${productId}`,
              err);
        }
        return;
      }

      const product = event.data.after.data();
      try {
        await upsertRetailProduct(
            productToRetailProduct(storeId, productId, product));
        logger.info(`onProductWrite: upserted product ${storeId}/${productId}`);
      } catch (err) {
        logger.error(
            `onProductWrite: failed to upsert product ${storeId}/${productId}`,
            err);
      }
    },
);

// ---------------------------------------------------------------------------
// logUserEvent — callable (fire-and-forget from Flutter)
// ---------------------------------------------------------------------------

exports.logUserEvent = onCall(async (request) => {
  const {
    eventType,
    userId,
    visitorId,
    productIds = [],
    attributionToken = "",
    purchaseAmount,
    transactionId,
  } = request.data;

  if (!eventType || !visitorId) {
    return {success: false};
  }

  try {
    const client = getEventClient();

    const productDetails = productIds.map((id) => ({product: {id}}));

    const userEvent = {
      eventType,
      visitorId,
      eventTime: {seconds: Math.floor(Date.now() / 1000), nanos: 0},
      userInfo: {
        userId: userId || "",
        isAuthenticated: !!userId,
      },
      productDetails,
      attributionToken,
    };

    if (eventType === "purchase-complete" && purchaseAmount != null) {
      userEvent.purchaseTransaction = {
        id: transactionId || `txn_${Date.now()}`,
        revenue: purchaseAmount,
        currencyCode: "LKR",
      };
    }

    await client.writeUserEvent({parent: PARENT, userEvent});
    return {success: true};
  } catch (err) {
    logger.warn("logUserEvent: failed to write event", err.message);
    return {success: false};
  }
});

// ---------------------------------------------------------------------------
// getRecommendations — callable from Flutter
// ---------------------------------------------------------------------------

exports.getRecommendations = onCall(async (request) => {
  const {
    placement,
    userId,
    visitorId = "anonymous",
    productIds = [],
    filter = "",
  } = request.data;

  if (!placement) {
    throw new HttpsError("invalid-argument", "placement is required");
  }

  try {
    const client = getPredictionClient();

    const productDetails = productIds.map((id) => ({product: {id}}));

    const [response] = await client.predict({
      placement: `${PARENT}/servingConfigs/${placement}`,
      userEvent: {
        eventType: "detail-page-view",
        visitorId,
        userInfo: {userId: userId || "", isAuthenticated: !!userId},
        eventTime: {seconds: Math.floor(Date.now() / 1000), nanos: 0},
        productDetails,
      },
      filter,
      pageSize: 10,
      validateOnly: false,
    });

    const results = (response.results || []).map((r) => r.id);
    return {results, attributionToken: response.attributionToken || ""};
  } catch (err) {
    logger.warn(
        `getRecommendations: predict failed for ${placement}`, err.message);
    return {results: [], attributionToken: ""};
  }
});
