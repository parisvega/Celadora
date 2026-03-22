var STORAGE_COLLECTION = "celadora";
var STORAGE_KEY = "authority_state";

function InitModule(ctx, logger, nk, initializer) {
  initializer.registerRpc("celadora_connect", function (ctx, logger, nk, payload) {
    return jsonRpc(connectRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_sync_player_state", function (ctx, logger, nk, payload) {
    return jsonRpc(syncStateRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_fetch_market_listings", function (ctx, logger, nk, payload) {
    return jsonRpc(fetchMarketRpc(ctx, nk));
  });
  initializer.registerRpc("celadora_submit_market_order", function (ctx, logger, nk, payload) {
    return jsonRpc(submitMarketOrderRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_submit_reward_claim", function (ctx, logger, nk, payload) {
    return jsonRpc(submitRewardClaimRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_submit_craft_request", function (ctx, logger, nk, payload) {
    return jsonRpc(submitCraftRequestRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_submit_combat_event", function (ctx, logger, nk, payload) {
    return jsonRpc(submitCombatEventRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_sync_resource_catalog", function (ctx, logger, nk, payload) {
    return jsonRpc(syncResourceCatalogRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_submit_resource_mine", function (ctx, logger, nk, payload) {
    return jsonRpc(submitResourceMineRpc(ctx, payload, nk));
  });
  initializer.registerRpc("celadora_submit_enemy_defeat", function (ctx, logger, nk, payload) {
    return jsonRpc(submitEnemyDefeatRpc(ctx, payload, nk));
  });
  logger.info("Celadora Nakama authority module loaded.");
}

function connectRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var record = loadAuthorityRecord(ctx, nk);
  ensureMarketSeeded(record.state);
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    mode: "nakama",
    session_id: String(ctx.userId),
    state_present: record.statePresent,
    snapshot: snapshot(record.state)
  });
}

function syncStateRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  var incomingState = isObject(body.state) ? body.state : {};
  var forceBootstrap = Boolean(body.force_bootstrap);

  if (forceBootstrap || !record.statePresent) {
    record.state = normalizeState(incomingState);
    record.state.claimed_rewards = {};
    record.state.resource_catalog = {};
    record.state.reserved_reward_claims = {};
    record.state.mined_resource_ids = resourceFlagsToIds(record.state.world_state);
    record.state.defeated_enemy_ids = enemyFlagsToIds(record.state.world_state);
    record.statePresent = true;
    ensureMarketSeeded(record.state);
    persistAuthorityRecord(ctx, nk, record.state);
    return ok({ snapshot: snapshot(record.state) });
  }

  record.state.player_state = sanitizePlayerState(incomingState.player_state || record.state.player_state);
  record.state.world_state = sanitizeWorldState(incomingState.world_state || record.state.world_state);
  record.state.unlocked_lore = sanitizeStringArray(incomingState.unlocked_lore || record.state.unlocked_lore);
  record.state.timestamp = typeof incomingState.timestamp === "string" ? incomingState.timestamp : record.state.timestamp;
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({ snapshot: snapshot(record.state) });
}

function fetchMarketRpc(ctx, nk) {
  ensureUserContext(ctx);
  var record = loadAuthorityRecord(ctx, nk);
  ensureMarketSeeded(record.state);
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    listings: deepClone(record.state.marketplace.listings),
    snapshot: economySnapshot(record.state)
  });
}

function submitRewardClaimRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  var itemId = typeof body.item_id === "string" ? body.item_id.trim() : "";
  var claimId = typeof body.claim_id === "string" ? body.claim_id.trim() : "";
  var quantity = Math.max(0, Number(body.quantity || 0));
  var credits = Math.max(0, Number(body.credits || 0));
  if (claimId && isObject(record.state.reserved_reward_claims[claimId])) {
    var reserved = record.state.reserved_reward_claims[claimId];
    itemId = typeof reserved.item_id === "string" ? reserved.item_id.trim() : itemId;
    quantity = Math.max(0, Number(reserved.quantity || quantity));
    credits = Math.max(0, Number(reserved.credits || credits));
  }
  if (!itemId && credits <= 0) {
    return fail("Reward claim must include an item or credits.");
  }
  if (itemId && quantity <= 0) {
    return fail("Reward claim quantity must be at least 1.");
  }
  if (claimId && record.state.claimed_rewards[claimId]) {
    return fail("Reward claim already consumed.");
  }
  if (claimId) {
    record.state.claimed_rewards[claimId] = Date.now();
    delete record.state.reserved_reward_claims[claimId];
  }

  if (itemId) {
    record.state.inventory[itemId] = Number(record.state.inventory[itemId] || 0) + quantity;
  }
  var grantedCredits = applyCreditGain(record.state, credits);
  record.statePresent = true;
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    granted_item_id: itemId,
    granted_quantity: quantity,
    granted_credits: grantedCredits,
    snapshot: economySnapshot(record.state)
  });
}

function syncResourceCatalogRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  var resources = Array.isArray(body.resources) ? body.resources : [];
  var registered = 0;
  for (var i = 0; i < resources.length; i++) {
    var resource = sanitizeResourceDef(resources[i]);
    if (!resource) {
      continue;
    }
    record.state.resource_catalog[resource.resource_id] = resource;
    registered += 1;
  }
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({ registered: registered });
}

function submitResourceMineRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  var resourceBody = isObject(body.resource) ? body.resource : {};
  var resourceId = typeof resourceBody.resource_id === "string" ? resourceBody.resource_id.trim() : "";
  if (!resourceId) {
    return fail("Resource ID is required.");
  }
  if (record.state.mined_resource_ids[resourceId]) {
    return fail("Resource already mined.");
  }
  var resource = record.state.resource_catalog[resourceId];
  if (!isObject(resource)) {
    return fail("Unknown resource node.");
  }
  var claimId = "resource:" + resourceId;
  record.state.reserved_reward_claims[claimId] = {
    item_id: resource.item_id,
    quantity: Number(resource.quantity || 1),
    credits: Number(resource.credits || 0),
    source: "resource:" + resourceId
  };
  record.state.mined_resource_ids[resourceId] = Date.now();
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    resource_id: resourceId,
    claim_id: claimId,
    item_id: resource.item_id,
    quantity: Number(resource.quantity || 1),
    credits: Number(resource.credits || 0)
  });
}

function submitEnemyDefeatRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  var enemyBody = isObject(body.enemy) ? body.enemy : {};
  var enemyInstanceId = typeof enemyBody.enemy_instance_id === "string" ? enemyBody.enemy_instance_id.trim() : "";
  var enemyId = typeof enemyBody.enemy_id === "string" ? enemyBody.enemy_id.trim() : "";
  if (!enemyInstanceId) {
    return fail("Enemy instance ID is required.");
  }
  if (!enemyId) {
    return fail("Enemy ID is required.");
  }
  if (record.state.defeated_enemy_ids[enemyInstanceId]) {
    return fail("Enemy already defeated.");
  }
  var enemyDef = getEnemyDefs()[enemyId];
  if (!enemyDef) {
    return fail("Unknown enemy ID.");
  }

  record.state.defeated_enemy_ids[enemyInstanceId] = Date.now();
  var grants = [];
  for (var i = 0; i < (enemyDef.drops || []).length; i++) {
    var row = enemyDef.drops[i];
    if (!isObject(row)) {
      continue;
    }
    var itemId = typeof row.item_id === "string" ? row.item_id.trim() : "";
    var quantity = Math.max(1, Number(row.quantity || 1));
    if (!itemId || !getItemDefs()[itemId]) {
      continue;
    }
    record.state.inventory[itemId] = Number(record.state.inventory[itemId] || 0) + quantity;
    grants.push({
      item_id: itemId,
      quantity: quantity
    });
  }
  var grantedCredits = applyCreditGain(record.state, Math.max(0, Number(enemyDef.credit_reward || 0)));
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    enemy_instance_id: enemyInstanceId,
    enemy_id: enemyId,
    grants: grants,
    credits: grantedCredits,
    reason: "Salvaged " + enemyId,
    snapshot: economySnapshot(record.state)
  });
}

function submitCraftRequestRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  var recipeId = typeof body.recipe_id === "string" ? body.recipe_id.trim() : "";
  var recipes = getRecipeDefs();
  var recipe = recipes[recipeId];
  if (!recipe) {
    return fail("Unknown recipe.");
  }

  var validation = validateRecipe(recipe, record.state.inventory);
  if (!validation.ok) {
    return fail(validation.reason);
  }

  for (var ingredientId in recipe.ingredients) {
    consumeInventoryItem(record.state.inventory, ingredientId, Number(recipe.ingredients[ingredientId]));
  }

  var distinctDustCount = Number((recipe.special || {}).distinct_dust_count || 0);
  if (distinctDustCount > 0) {
    var dustIds = getAvailableDustIds(record.state.inventory);
    for (var i = 0; i < Math.min(distinctDustCount, dustIds.length); i++) {
      consumeInventoryItem(record.state.inventory, dustIds[i], 1);
    }
  }

  for (var outputId in (recipe.outputs || {})) {
    record.state.inventory[outputId] = Number(record.state.inventory[outputId] || 0) + Number(recipe.outputs[outputId]);
  }

  record.statePresent = true;
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    recipe_id: recipeId,
    recipe_name: String(recipe.name || recipeId),
    outputs: deepClone(recipe.outputs || {}),
    snapshot: economySnapshot(record.state)
  });
}

function submitMarketOrderRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  ensureMarketSeeded(record.state);
  var action = typeof body.action === "string" ? body.action.trim().toLowerCase() : "";
  if (action === "buy") {
    return submitBuyOrder(record, body, ctx, nk);
  }
  if (action === "sell") {
    return submitSellOrder(record, body, ctx, nk);
  }
  return fail("Unknown market action.");
}

function submitCombatEventRpc(ctx, payload, nk) {
  ensureUserContext(ctx);
  var body = parsePayload(payload);
  var record = loadAuthorityRecord(ctx, nk);
  if (!Array.isArray(record.state.combat_events)) {
    record.state.combat_events = [];
  }
  record.state.combat_events.push({
    timestamp_unix_sec: Math.floor(Date.now() / 1000),
    event: body
  });
  if (record.state.combat_events.length > 128) {
    record.state.combat_events = record.state.combat_events.slice(-128);
  }
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({ accepted: true });
}

function submitBuyOrder(record, body, ctx, nk) {
  var listingId = typeof body.listing_id === "string" ? body.listing_id.trim() : "";
  var quantity = Math.max(0, Number(body.quantity || 0));
  if (!listingId) {
    return fail("Listing ID is required.");
  }
  if (quantity <= 0) {
    return fail("Quantity must be at least 1.");
  }

  var listings = record.state.marketplace.listings;
  var listingIndex = -1;
  for (var i = 0; i < listings.length; i++) {
    if (String(listings[i].id) === listingId) {
      listingIndex = i;
      break;
    }
  }
  if (listingIndex < 0) {
    return fail("Listing not found.");
  }

  var listing = listings[listingIndex];
  if (Number(listing.quantity) < quantity) {
    return fail("Listing does not have enough stock.");
  }
  var total = Number(listing.unit_price) * quantity;
  if (Number(record.state.credits) < total) {
    return fail("Not enough Celador Credits.");
  }

  record.state.credits -= total;
  record.state.inventory[listing.item_id] = Number(record.state.inventory[listing.item_id] || 0) + quantity;
  listing.quantity -= quantity;
  if (listing.quantity <= 0) {
    listings.splice(listingIndex, 1);
  }
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    accepted: true,
    reason: "Purchased " + quantity + " x " + listing.item_id,
    listings: deepClone(record.state.marketplace.listings),
    snapshot: economySnapshot(record.state)
  });
}

function submitSellOrder(record, body, ctx, nk) {
  var itemId = typeof body.item_id === "string" ? body.item_id.trim() : "";
  var quantity = Math.max(0, Number(body.quantity || 0));
  var unitPrice = Math.max(0, Number(body.unit_price || 0));
  if (!itemId) {
    return fail("Item ID is required.");
  }
  if (quantity <= 0) {
    return fail("Quantity must be at least 1.");
  }
  if (unitPrice <= 0) {
    return fail("Unit price must be positive.");
  }
  if (Number(record.state.inventory[itemId] || 0) < quantity) {
    return fail("You do not have enough of this item.");
  }

  consumeInventoryItem(record.state.inventory, itemId, quantity);
  var listing = {
    id: allocateListingId(record.state.marketplace),
    item_id: itemId,
    quantity: quantity,
    unit_price: unitPrice,
    seller: typeof body.seller === "string" && body.seller.trim() ? body.seller.trim() : "Player"
  };
  record.state.marketplace.listings.push(listing);
  record.statePresent = true;
  persistAuthorityRecord(ctx, nk, record.state);
  return ok({
    accepted: true,
    reason: "Listed " + quantity + " x " + itemId,
    listing: deepClone(listing),
    listings: deepClone(record.state.marketplace.listings),
    snapshot: economySnapshot(record.state)
  });
}

function ensureUserContext(ctx) {
  if (!ctx.userId) {
    throw new Error("RPC requires an authenticated user context.");
  }
}

function loadAuthorityRecord(ctx, nk) {
  var objects = nk.storageRead([{
    collection: STORAGE_COLLECTION,
    key: STORAGE_KEY,
    userId: String(ctx.userId)
  }]);
  if (!objects || objects.length === 0) {
    return {
      statePresent: false,
      state: defaultState()
    };
  }
  var value = objects[0].value || {};
  return {
    statePresent: true,
    state: normalizeState(value)
  };
}

function persistAuthorityRecord(ctx, nk, state) {
  nk.storageWrite([{
    collection: STORAGE_COLLECTION,
    key: STORAGE_KEY,
    userId: String(ctx.userId),
    value: state,
    permissionRead: 1,
    permissionWrite: 0
  }]);
}

function defaultState() {
  return normalizeState({});
}

function normalizeState(raw) {
  var state = isObject(raw) ? deepClone(raw) : {};
  return {
    inventory: sanitizeInventory(state.inventory),
    credits: Math.max(0, Number(state.credits || 0)),
    marketplace: sanitizeMarketplaceState(state.marketplace),
    player_state: sanitizePlayerState(state.player_state),
    world_state: sanitizeWorldState(state.world_state),
    unlocked_lore: sanitizeStringArray(state.unlocked_lore),
    timestamp: typeof state.timestamp === "string" ? state.timestamp : "",
    claimed_rewards: isObject(state.claimed_rewards) ? deepClone(state.claimed_rewards) : {},
    resource_catalog: isObject(state.resource_catalog) ? deepClone(state.resource_catalog) : {},
    reserved_reward_claims: isObject(state.reserved_reward_claims) ? deepClone(state.reserved_reward_claims) : {},
    mined_resource_ids: isObject(state.mined_resource_ids) ? deepClone(state.mined_resource_ids) : {},
    defeated_enemy_ids: isObject(state.defeated_enemy_ids) ? deepClone(state.defeated_enemy_ids) : {},
    combat_events: Array.isArray(state.combat_events) ? deepClone(state.combat_events) : []
  };
}

function snapshot(state) {
  ensureMarketSeeded(state);
  return deepClone({
    inventory: state.inventory,
    credits: state.credits,
    marketplace: state.marketplace,
    player_state: state.player_state,
    world_state: state.world_state,
    unlocked_lore: state.unlocked_lore,
    timestamp: state.timestamp
  });
}

function economySnapshot(state) {
  ensureMarketSeeded(state);
  return deepClone({
    inventory: state.inventory,
    credits: state.credits,
    marketplace: state.marketplace
  });
}

function ensureMarketSeeded(state) {
  if (!state.marketplace || !Array.isArray(state.marketplace.listings)) {
    state.marketplace = { listings: [], next_listing_id: 1 };
  }
  if (state.marketplace.listings.length > 0) {
    return;
  }
  state.marketplace.listings = [
    { id: allocateListingId(state.marketplace), item_id: "dust_blue", quantity: 12, unit_price: 7, seller: "Frontier Guild" },
    { id: allocateListingId(state.marketplace), item_id: "energy_crystal", quantity: 6, unit_price: 20, seller: "Makuna Exchange" },
    { id: allocateListingId(state.marketplace), item_id: "alloy", quantity: 3, unit_price: 50, seller: "Ridge Smithy" }
  ];
}

function allocateListingId(marketplace) {
  var nextId = Math.max(1, Number(marketplace.next_listing_id || 1));
  marketplace.next_listing_id = nextId + 1;
  return "listing_" + nextId;
}

function applyCreditGain(state, baseAmount) {
  if (baseAmount <= 0) {
    return 0;
  }
  var granted = Math.max(0, Math.round(baseAmount * (1 + getModifierTotal(state.inventory, "credit_gain_multiplier"))));
  state.credits += granted;
  return granted;
}

function getModifierTotal(inventory, statKey) {
  var items = getItemDefs();
  var total = 0;
  for (var itemId in inventory) {
    if (Number(inventory[itemId]) <= 0) {
      continue;
    }
    var item = items[itemId];
    if (!item || !isObject(item.modifier)) {
      continue;
    }
    total += Number(item.modifier[statKey] || 0);
  }
  return total;
}

function validateRecipe(recipe, inventory) {
  var ingredients = recipe.ingredients || {};
  for (var itemId in ingredients) {
    var amount = Number(ingredients[itemId] || 0);
    if (Number(inventory[itemId] || 0) < amount) {
      return { ok: false, reason: "Missing " + itemId + " x" + amount };
    }
  }

  var distinctDustCount = Number(((recipe.special || {}).distinct_dust_count) || 0);
  if (distinctDustCount > 0 && getAvailableDustIds(inventory).length < distinctDustCount) {
    return { ok: false, reason: "Need " + distinctDustCount + " distinct moon dust types." };
  }
  return { ok: true, reason: "" };
}

function getAvailableDustIds(inventory) {
  var items = getItemDefs();
  var ids = [];
  for (var itemId in inventory) {
    if (Number(inventory[itemId]) <= 0) {
      continue;
    }
    var item = items[itemId];
    if (!item || !Array.isArray(item.tags) || item.tags.indexOf("dust") === -1) {
      continue;
    }
    ids.push(itemId);
  }
  ids.sort();
  return ids;
}

function consumeInventoryItem(inventory, itemId, quantity) {
  var next = Number(inventory[itemId] || 0) - quantity;
  if (next <= 0) {
    delete inventory[itemId];
    return;
  }
  inventory[itemId] = next;
}

function sanitizeInventory(raw) {
  var items = getItemDefs();
  var out = {};
  if (!isObject(raw)) {
    return out;
  }
  for (var itemId in raw) {
    var key = String(itemId).trim();
    if (!key || !items[key]) {
      continue;
    }
    var quantity = Math.max(0, Number(raw[itemId] || 0));
    if (quantity <= 0) {
      continue;
    }
    out[key] = quantity;
  }
  return out;
}

function sanitizeMarketplaceState(raw) {
  var out = { listings: [], next_listing_id: 1 };
  if (!isObject(raw)) {
    return out;
  }
  if (Array.isArray(raw.listings)) {
    out.listings = raw.listings
      .filter(isObject)
      .map(function (listing) {
        return {
          id: String(listing.id || "").trim(),
          item_id: String(listing.item_id || "").trim(),
          quantity: Math.max(0, Number(listing.quantity || 0)),
          unit_price: Math.max(0, Number(listing.unit_price || 0)),
          seller: typeof listing.seller === "string" ? listing.seller : "Unknown"
        };
      })
      .filter(function (listing) {
        return listing.id && listing.item_id && listing.quantity > 0 && listing.unit_price > 0;
      });
  }
  out.next_listing_id = Math.max(1, Number(raw.next_listing_id || (out.listings.length + 1)));
  return out;
}

function sanitizePlayerState(raw) {
  return isObject(raw) ? deepClone(raw) : {};
}

function sanitizeWorldState(raw) {
  var out = {};
  if (!isObject(raw)) {
    return out;
  }
  for (var key in raw) {
    var flagId = String(key).trim();
    if (!flagId) {
      continue;
    }
    out[flagId] = Boolean(raw[key]);
  }
  return out;
}

function sanitizeResourceDef(raw) {
  if (!isObject(raw)) {
    return null;
  }
  var resourceId = typeof raw.resource_id === "string" ? raw.resource_id.trim() : "";
  var itemId = typeof raw.item_id === "string" ? raw.item_id.trim() : "";
  if (!resourceId || !itemId || !getItemDefs()[itemId]) {
    return null;
  }
  return {
    resource_id: resourceId,
    item_id: itemId,
    quantity: Math.max(1, Number(raw.quantity || 1)),
    credits: Math.max(0, Number(raw.credits || 0)),
    position: Array.isArray(raw.position) ? deepClone(raw.position) : []
  };
}

function resourceFlagsToIds(worldState) {
  var out = {};
  for (var flagId in (worldState || {})) {
    if (!Object.prototype.hasOwnProperty.call(worldState, flagId)) {
      continue;
    }
    var flagName = String(flagId || "").trim();
    if (flagName.indexOf("resource_mined:") !== 0 || !Boolean(worldState[flagId])) {
      continue;
    }
    var resourceId = flagName.slice("resource_mined:".length).trim();
    if (!resourceId) {
      continue;
    }
    out[resourceId] = Date.now();
  }
  return out;
}

function enemyFlagsToIds(worldState) {
  var out = {};
  for (var flagId in (worldState || {})) {
    if (!Object.prototype.hasOwnProperty.call(worldState, flagId)) {
      continue;
    }
    var flagName = String(flagId || "").trim();
    if (flagName.indexOf("enemy_defeated:") !== 0 || !Boolean(worldState[flagId])) {
      continue;
    }
    var enemyInstanceId = flagName.slice("enemy_defeated:".length).trim();
    if (!enemyInstanceId) {
      continue;
    }
    out[enemyInstanceId] = Date.now();
  }
  return out;
}

function sanitizeStringArray(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }
  var seen = {};
  var out = [];
  for (var i = 0; i < raw.length; i++) {
    var text = String(raw[i] || "").trim();
    if (!text || seen[text]) {
      continue;
    }
    seen[text] = true;
    out.push(text);
  }
  return out;
}

function parsePayload(payload) {
  if (!payload) {
    return {};
  }
  if (typeof payload === "string") {
    return JSON.parse(payload);
  }
  if (isObject(payload)) {
    return payload;
  }
  return {};
}

function ok(data) {
  return { ok: true, error: "", data: data };
}

function fail(error) {
  return { ok: false, error: error, data: {} };
}

function jsonRpc(payload) {
  return JSON.stringify(payload);
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

var cachedItemDefs = null;
var cachedRecipeDefs = null;
var cachedEnemyDefs = null;

function getItemDefs() {
  if (cachedItemDefs !== null) {
    return cachedItemDefs;
  }
  cachedItemDefs = {
    "dust_blue": { tags: ["dust"], modifier: { "stamina_regen": 0.10 } },
    "dust_green": { tags: ["dust"], modifier: { "health_regen": 0.08 } },
    "dust_red": { tags: ["dust"], modifier: { "damage_bonus": 0.10 } },
    "dust_orange": { tags: ["dust"], modifier: { "mining_speed": 0.12 } },
    "dust_yellow": { tags: ["dust"], modifier: { "move_speed": 0.08 } },
    "dust_white": { tags: ["dust"], modifier: { "shield_regen": 0.10 } },
    "dust_black": { tags: ["dust"], modifier: { "aggro_radius_multiplier": -0.10 } },
    "dust_silver": { tags: ["dust"], modifier: { "credit_gain_multiplier": 0.15 } },
    "energy_crystal": { tags: [] },
    "alloy": { tags: [] },
    "moonblade_prototype": { tags: [] },
    "dream_seed": { tags: [] },
    "bot_scrap": { tags: [] }
  };
  return cachedItemDefs;
}

function getRecipeDefs() {
  if (cachedRecipeDefs !== null) {
    return cachedRecipeDefs;
  }
  cachedRecipeDefs = {
    "alloy_recipe": {
      name: "Forge Celadora Alloy",
      ingredients: { "energy_crystal": 1 },
      special: { "distinct_dust_count": 2 },
      outputs: { "alloy": 1 }
    },
    "moonblade_recipe": {
      name: "Moonblade (Prototype)",
      ingredients: { "alloy": 1, "energy_crystal": 1, "dream_seed": 1 },
      outputs: { "moonblade_prototype": 1 }
    }
  };
  return cachedRecipeDefs;
}

function getEnemyDefs() {
  if (cachedEnemyDefs !== null) {
    return cachedEnemyDefs;
  }
  cachedEnemyDefs = {
    "greegion_miner_bot": {
      drops: [{ item_id: "bot_scrap", quantity: 1 }],
      credit_reward: 10
    }
  };
  return cachedEnemyDefs;
}
