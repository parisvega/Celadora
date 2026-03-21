import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, "../..");
const PORT = Number.parseInt(process.env.CELADORA_AUTHORITY_PORT ?? "8787", 10);
const STATE_FILE = process.env.CELADORA_AUTHORITY_STATE ?? path.join(ROOT, "artifacts/authority/state.local.json");

const itemDefs = loadJson(path.join(ROOT, "data/items.json"));
const recipeDefs = loadJson(path.join(ROOT, "data/recipes.json"));
const itemMap = new Map(itemDefs.map((item) => [String(item.id), item]));
const recipeMap = new Map(recipeDefs.map((recipe) => [String(recipe.id), recipe]));

let store = loadStore();

const server = http.createServer(async (req, res) => {
  setCorsHeaders(res);
  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  try {
    const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "127.0.0.1"}`);
    const body = await readJsonBody(req);
    const response = routeRequest(req.method ?? "GET", url.pathname, body);
    writeJson(res, response.statusCode, response.payload);
  } catch (error) {
    writeJson(res, 500, {
      ok: false,
      error: error instanceof Error ? error.message : "Authority server error.",
      data: {},
    });
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[authority] listening on http://127.0.0.1:${PORT}`);
  console.log(`[authority] state file ${STATE_FILE}`);
});

function routeRequest(method, pathname, body) {
  switch (`${method} ${pathname}`) {
    case "POST /connect":
      return ok({
        mode: "http_authority",
        session_id: store.session_id,
        state_present: Boolean(store.state_present),
        snapshot: snapshot(),
      });
    case "POST /sync/player_state":
      return handleSyncState(body);
    case "GET /market/listings":
      ensureMarketSeeded();
      persistStore();
      return ok({
        listings: snapshot().marketplace.listings,
        snapshot: economySnapshot(),
      });
    case "POST /market/order":
      return handleMarketOrder(body);
    case "POST /reward/claim":
      return handleRewardClaim(body);
    case "POST /craft/execute":
      return handleCraftExecute(body);
    case "POST /world/resources/sync":
      return handleResourceCatalogSync(body);
    case "POST /world/resources/mine":
      return handleResourceMine(body);
    case "POST /combat/event":
      appendCombatEvent(body);
      persistStore();
      return ok({ accepted: true });
    default:
      return {
        statusCode: 404,
        payload: { ok: false, error: `Unknown route ${method} ${pathname}`, data: {} },
      };
  }
}

function handleSyncState(body) {
  const incoming = isObject(body.state) ? body.state : {};
  const forceBootstrap = Boolean(body.force_bootstrap);
  if (forceBootstrap || !store.state_present) {
    store.player = normalizeState(incoming);
    store.claimed_rewards = {};
    store.resource_catalog = {};
    store.reserved_reward_claims = {};
    store.mined_resource_ids = resourceFlagsToIds(store.player.world_state);
    store.state_present = true;
    ensureMarketSeeded();
    persistStore();
    return ok({ snapshot: snapshot() });
  }

  store.player.player_state = sanitizePlayerState(incoming.player_state ?? store.player.player_state);
  store.player.world_state = sanitizeWorldState(incoming.world_state ?? store.player.world_state);
  store.player.unlocked_lore = sanitizeStringArray(incoming.unlocked_lore ?? store.player.unlocked_lore);
  store.player.timestamp = typeof incoming.timestamp === "string" ? incoming.timestamp : store.player.timestamp;
  persistStore();
  return ok({ snapshot: snapshot() });
}

function handleRewardClaim(body) {
  const itemId = typeof body.item_id === "string" ? body.item_id.trim() : "";
  const claimId = typeof body.claim_id === "string" ? body.claim_id.trim() : "";
  let quantity = Math.max(0, Number.parseInt(body.quantity ?? "0", 10));
  let credits = Math.max(0, Number.parseInt(body.credits ?? "0", 10));
  let resolvedItemId = itemId;
  if (claimId && isObject(store.reserved_reward_claims[claimId])) {
    const reserved = store.reserved_reward_claims[claimId];
    resolvedItemId = typeof reserved.item_id === "string" ? reserved.item_id.trim() : "";
    quantity = Math.max(0, Number.parseInt(reserved.quantity ?? quantity, 10));
    credits = Math.max(0, Number.parseInt(reserved.credits ?? credits, 10));
  }
  if (!resolvedItemId && credits <= 0) {
    return fail(400, "Reward claim must include an item or credits.");
  }
  if (resolvedItemId && quantity <= 0) {
    return fail(400, "Reward claim quantity must be at least 1.");
  }
  if (resolvedItemId && !itemMap.has(resolvedItemId)) {
    return fail(400, "Unknown item reward.");
  }
  if (claimId && store.claimed_rewards[claimId]) {
    return fail(409, "Reward claim already consumed.");
  }
  if (claimId) {
    store.claimed_rewards[claimId] = Math.floor(Date.now() / 1000);
    delete store.reserved_reward_claims[claimId];
  }

  if (resolvedItemId) {
    store.player.inventory[resolvedItemId] = Number(store.player.inventory[resolvedItemId] ?? 0) + quantity;
  }
  const grantedCredits = applyCreditGain(credits);
  store.state_present = true;
  persistStore();
  return ok({
    granted_item_id: resolvedItemId,
    granted_quantity: quantity,
    granted_credits: grantedCredits,
    snapshot: economySnapshot(),
  });
}

function handleResourceCatalogSync(body) {
  const resources = Array.isArray(body.resources) ? body.resources : [];
  let registered = 0;
  for (const row of resources) {
    const resource = sanitizeResourceDef(row);
    if (!resource) {
      continue;
    }
    store.resource_catalog[resource.resource_id] = resource;
    registered += 1;
  }
  persistStore();
  return ok({ registered });
}

function handleResourceMine(body) {
  const resourceBody = isObject(body.resource) ? body.resource : {};
  const resourceId = typeof resourceBody.resource_id === "string" ? resourceBody.resource_id.trim() : "";
  if (!resourceId) {
    return fail(400, "Resource ID is required.");
  }
  if (store.mined_resource_ids[resourceId]) {
    return fail(409, "Resource already mined.");
  }
  const resource = store.resource_catalog[resourceId];
  if (!isObject(resource)) {
    return fail(404, "Unknown resource node.");
  }
  const claimId = `resource:${resourceId}`;
  store.reserved_reward_claims[claimId] = {
    item_id: resource.item_id,
    quantity: Number(resource.quantity ?? 1),
    credits: Number(resource.credits ?? 0),
    source: `resource:${resourceId}`,
  };
  store.mined_resource_ids[resourceId] = Math.floor(Date.now() / 1000);
  persistStore();
  return ok({
    resource_id: resourceId,
    claim_id: claimId,
    item_id: resource.item_id,
    quantity: Number(resource.quantity ?? 1),
    credits: Number(resource.credits ?? 0),
  });
}

function handleCraftExecute(body) {
  const recipeId = typeof body.recipe_id === "string" ? body.recipe_id.trim() : "";
  const recipe = recipeMap.get(recipeId);
  if (!recipe) {
    return fail(400, "Unknown recipe.");
  }

  const validation = validateRecipe(recipe, store.player.inventory);
  if (!validation.ok) {
    return fail(400, validation.reason);
  }

  for (const [itemId, amount] of Object.entries(recipe.ingredients ?? {})) {
    consumeInventoryItem(itemId, Number(amount));
  }

  const distinctDustCount = Number(recipe.special?.distinct_dust_count ?? 0);
  if (distinctDustCount > 0) {
    const dustIds = getAvailableDustIds(store.player.inventory);
    for (const dustId of dustIds.slice(0, distinctDustCount)) {
      consumeInventoryItem(dustId, 1);
    }
  }

  for (const [itemId, amount] of Object.entries(recipe.outputs ?? {})) {
    store.player.inventory[itemId] = Number(store.player.inventory[itemId] ?? 0) + Number(amount);
  }

  store.state_present = true;
  persistStore();
  return ok({
    recipe_id: recipeId,
    recipe_name: String(recipe.name ?? recipeId),
    outputs: deepClone(recipe.outputs ?? {}),
    snapshot: economySnapshot(),
  });
}

function handleMarketOrder(body) {
  const action = typeof body.action === "string" ? body.action.trim().toLowerCase() : "";
  if (action === "buy") {
    return handleBuyOrder(body);
  }
  if (action === "sell") {
    return handleSellOrder(body);
  }
  return fail(400, "Unknown market action.");
}

function handleBuyOrder(body) {
  const listingId = typeof body.listing_id === "string" ? body.listing_id.trim() : "";
  const quantity = Math.max(0, Number.parseInt(body.quantity ?? "0", 10));
  if (!listingId) {
    return fail(400, "Listing ID is required.");
  }
  if (quantity <= 0) {
    return fail(400, "Quantity must be at least 1.");
  }

  const listings = store.player.marketplace.listings;
  const index = listings.findIndex((listing) => String(listing.id) === listingId);
  if (index < 0) {
    return fail(404, "Listing not found.");
  }

  const listing = listings[index];
  if (Number(listing.quantity) < quantity) {
    return fail(400, "Listing does not have enough stock.");
  }

  const total = Number(listing.unit_price) * quantity;
  if (Number(store.player.credits) < total) {
    return fail(400, "Not enough Celador Credits.");
  }

  store.player.credits -= total;
  store.player.inventory[listing.item_id] = Number(store.player.inventory[listing.item_id] ?? 0) + quantity;
  listing.quantity -= quantity;
  if (listing.quantity <= 0) {
    listings.splice(index, 1);
  }

  persistStore();
  return ok({
    accepted: true,
    reason: `Purchased ${quantity} x ${listing.item_id}`,
    listings: deepClone(store.player.marketplace.listings),
    snapshot: economySnapshot(),
  });
}

function handleSellOrder(body) {
  const itemId = typeof body.item_id === "string" ? body.item_id.trim() : "";
  const quantity = Math.max(0, Number.parseInt(body.quantity ?? "0", 10));
  const unitPrice = Math.max(0, Number.parseInt(body.unit_price ?? "0", 10));
  if (!itemId) {
    return fail(400, "Item ID is required.");
  }
  if (!itemMap.has(itemId)) {
    return fail(400, "Unknown item ID.");
  }
  if (quantity <= 0) {
    return fail(400, "Quantity must be at least 1.");
  }
  if (unitPrice <= 0) {
    return fail(400, "Unit price must be positive.");
  }
  if (Number(store.player.inventory[itemId] ?? 0) < quantity) {
    return fail(400, "You do not have enough of this item.");
  }

  consumeInventoryItem(itemId, quantity);
  const listing = {
    id: nextListingId(),
    item_id: itemId,
    quantity,
    unit_price: unitPrice,
    seller: typeof body.seller === "string" && body.seller.trim() ? body.seller.trim() : "Player",
  };
  store.player.marketplace.listings.push(listing);
  store.state_present = true;
  persistStore();
  return ok({
    accepted: true,
    reason: `Listed ${quantity} x ${itemId}`,
    listing: deepClone(listing),
    listings: deepClone(store.player.marketplace.listings),
    snapshot: economySnapshot(),
  });
}

function consumeInventoryItem(itemId, quantity) {
  const next = Number(store.player.inventory[itemId] ?? 0) - quantity;
  if (next <= 0) {
    delete store.player.inventory[itemId];
    return;
  }
  store.player.inventory[itemId] = next;
}

function validateRecipe(recipe, inventory) {
  for (const [itemId, amountRaw] of Object.entries(recipe.ingredients ?? {})) {
    const amount = Number(amountRaw);
    if (Number(inventory[itemId] ?? 0) < amount) {
      return { ok: false, reason: `Missing ${itemId} x${amount}` };
    }
  }

  const distinctDustCount = Number(recipe.special?.distinct_dust_count ?? 0);
  if (distinctDustCount > 0 && getAvailableDustIds(inventory).length < distinctDustCount) {
    return { ok: false, reason: `Need ${distinctDustCount} distinct moon dust types.` };
  }

  return { ok: true, reason: "" };
}

function getAvailableDustIds(inventory) {
  return Object.keys(inventory)
    .filter((itemId) => Number(inventory[itemId] ?? 0) > 0)
    .filter((itemId) => Array.isArray(itemMap.get(itemId)?.tags) && itemMap.get(itemId).tags.includes("dust"))
    .sort();
}

function applyCreditGain(baseAmount) {
  if (baseAmount <= 0) {
    return 0;
  }
  const multiplier = 1 + getModifierTotal("credit_gain_multiplier");
  const granted = Math.max(0, Math.round(baseAmount * multiplier));
  store.player.credits = Number(store.player.credits ?? 0) + granted;
  return granted;
}

function getModifierTotal(statKey) {
  let total = 0;
  for (const [itemId, quantity] of Object.entries(store.player.inventory)) {
    if (Number(quantity) <= 0) {
      continue;
    }
    const modifier = itemMap.get(itemId)?.modifier;
    if (!modifier || typeof modifier !== "object") {
      continue;
    }
    total += Number(modifier[statKey] ?? 0);
  }
  return total;
}

function appendCombatEvent(body) {
  if (!Array.isArray(store.event_log)) {
    store.event_log = [];
  }
  store.event_log.push({
    timestamp_unix_sec: Math.floor(Date.now() / 1000),
    event: deepClone(body),
  });
  if (store.event_log.length > 128) {
    store.event_log = store.event_log.slice(-128);
  }
}

function snapshot() {
  ensureMarketSeeded();
  return deepClone(store.player);
}

function economySnapshot() {
  ensureMarketSeeded();
  return deepClone({
    inventory: store.player.inventory,
    credits: store.player.credits,
    marketplace: store.player.marketplace,
  });
}

function ensureMarketSeeded() {
  if (!Array.isArray(store.player.marketplace?.listings)) {
    store.player.marketplace = { listings: [], next_listing_id: 1 };
  }
  if (store.player.marketplace.listings.length > 0) {
    return;
  }
  store.player.marketplace.listings = [
    { id: nextListingId(), item_id: "dust_blue", quantity: 12, unit_price: 7, seller: "Frontier Guild" },
    { id: nextListingId(), item_id: "energy_crystal", quantity: 6, unit_price: 20, seller: "Makuna Exchange" },
    { id: nextListingId(), item_id: "alloy", quantity: 3, unit_price: 50, seller: "Ridge Smithy" },
  ];
}

function nextListingId() {
  const nextId = Math.max(1, Number(store.player.marketplace.next_listing_id ?? 1));
  store.player.marketplace.next_listing_id = nextId + 1;
  return `listing_${nextId}`;
}

function loadStore() {
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  if (!fs.existsSync(STATE_FILE)) {
    return defaultStore();
  }
  try {
    const parsed = JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
    return normalizeStore(parsed);
  } catch {
    return defaultStore();
  }
}

function normalizeStore(raw) {
  const storeIn = isObject(raw) ? raw : {};
  return {
    session_id: typeof storeIn.session_id === "string" && storeIn.session_id ? storeIn.session_id : `http_${Math.floor(Date.now() / 1000)}`,
    state_present: Boolean(storeIn.state_present),
    player: normalizeState(storeIn.player),
    claimed_rewards: isObject(storeIn.claimed_rewards) ? deepClone(storeIn.claimed_rewards) : {},
    resource_catalog: isObject(storeIn.resource_catalog) ? deepClone(storeIn.resource_catalog) : {},
    reserved_reward_claims: isObject(storeIn.reserved_reward_claims) ? deepClone(storeIn.reserved_reward_claims) : {},
    mined_resource_ids: isObject(storeIn.mined_resource_ids) ? deepClone(storeIn.mined_resource_ids) : {},
    event_log: Array.isArray(storeIn.event_log) ? deepClone(storeIn.event_log) : [],
  };
}

function defaultStore() {
  return normalizeStore({});
}

function normalizeState(raw) {
  const state = isObject(raw) ? raw : {};
  return {
    inventory: sanitizeInventory(state.inventory),
    credits: Math.max(0, Number.parseInt(state.credits ?? "0", 10)),
    marketplace: sanitizeMarketplaceState(state.marketplace),
    player_state: sanitizePlayerState(state.player_state),
    world_state: sanitizeWorldState(state.world_state),
    unlocked_lore: sanitizeStringArray(state.unlocked_lore),
    timestamp: typeof state.timestamp === "string" ? state.timestamp : "",
  };
}

function sanitizeInventory(raw) {
  const inventory = {};
  if (!isObject(raw)) {
    return inventory;
  }
  for (const [itemIdRaw, quantityRaw] of Object.entries(raw)) {
    const itemId = String(itemIdRaw).trim();
    if (!itemId || !itemMap.has(itemId)) {
      continue;
    }
    const quantity = Math.max(0, Number.parseInt(quantityRaw ?? "0", 10));
    if (quantity <= 0) {
      continue;
    }
    inventory[itemId] = quantity;
  }
  return inventory;
}

function sanitizeMarketplaceState(raw) {
  const marketplace = { listings: [], next_listing_id: 1 };
  if (!isObject(raw)) {
    return marketplace;
  }
  if (Array.isArray(raw.listings)) {
    marketplace.listings = raw.listings
      .filter((listing) => isObject(listing))
      .map((listing) => ({
        id: String(listing.id ?? "").trim(),
        item_id: String(listing.item_id ?? "").trim(),
        quantity: Math.max(0, Number.parseInt(listing.quantity ?? "0", 10)),
        unit_price: Math.max(0, Number.parseInt(listing.unit_price ?? "0", 10)),
        seller: typeof listing.seller === "string" ? listing.seller : "Unknown",
      }))
      .filter((listing) => listing.id && listing.item_id && listing.quantity > 0 && listing.unit_price > 0);
  }
  marketplace.next_listing_id = Math.max(1, Number.parseInt(raw.next_listing_id ?? `${marketplace.listings.length + 1}`, 10));
  return marketplace;
}

function sanitizePlayerState(raw) {
  return isObject(raw) ? deepClone(raw) : {};
}

function sanitizeWorldState(raw) {
  if (!isObject(raw)) {
    return {};
  }
  const out = {};
  for (const [flagId, value] of Object.entries(raw)) {
    const key = String(flagId).trim();
    if (!key) {
      continue;
    }
    out[key] = Boolean(value);
  }
  return out;
}

function sanitizeResourceDef(raw) {
  if (!isObject(raw)) {
    return null;
  }
  const resourceId = typeof raw.resource_id === "string" ? raw.resource_id.trim() : "";
  const itemId = typeof raw.item_id === "string" ? raw.item_id.trim() : "";
  if (!resourceId || !itemId || !itemMap.has(itemId)) {
    return null;
  }
  return {
    resource_id: resourceId,
    item_id: itemId,
    quantity: Math.max(1, Number.parseInt(raw.quantity ?? "1", 10)),
    credits: Math.max(0, Number.parseInt(raw.credits ?? "0", 10)),
    position: Array.isArray(raw.position) ? deepClone(raw.position) : [],
  };
}

function resourceFlagsToIds(worldState) {
  const out = {};
  for (const [flagIdRaw, enabledRaw] of Object.entries(worldState || {})) {
    const flagId = String(flagIdRaw).trim();
    if (!flagId.startsWith("resource_mined:") || !Boolean(enabledRaw)) {
      continue;
    }
    const resourceId = flagId.slice("resource_mined:".length).trim();
    if (!resourceId) {
      continue;
    }
    out[resourceId] = Math.floor(Date.now() / 1000);
  }
  return out;
}

function sanitizeStringArray(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }
  const seen = new Set();
  const out = [];
  for (const value of raw) {
    const text = String(value ?? "").trim();
    if (!text || seen.has(text)) {
      continue;
    }
    seen.add(text);
    out.push(text);
  }
  return out;
}

function persistStore() {
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(store, null, 2));
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      if (chunks.length === 0) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch (error) {
        reject(new Error("Request body must be valid JSON."));
      }
    });
    req.on("error", reject);
  });
}

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function writeJson(res, statusCode, payload) {
  res.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload));
}

function setCorsHeaders(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function ok(data) {
  return {
    statusCode: 200,
    payload: {
      ok: true,
      error: "",
      data,
    },
  };
}

function fail(statusCode, error) {
  return {
    statusCode,
    payload: {
      ok: false,
      error,
      data: {},
    },
  };
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
