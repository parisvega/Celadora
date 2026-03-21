const baseUrl = process.env.CELADORA_AUTHORITY_URL ?? "http://127.0.0.1:8787";

async function main() {
  let response = await post("/connect", { profile: { name: "Smoke Tester" } });
  assertOk(response, "connect");

  response = await post("/sync/player_state", {
    force_bootstrap: true,
    state: {
      inventory: { dust_blue: 1, dust_green: 1, energy_crystal: 2, bot_scrap: 1, dream_seed: 1 },
      credits: 25,
      marketplace: {},
      player_state: { position: [0, 8, 0], health: 100, stamina: 100, shield: 0 },
      world_state: { ruins_terminal_primed: false },
      unlocked_lore: ["enoks_kingdom_ridge"],
      timestamp: "smoke"
    }
  });
  assertOk(response, "sync");

  response = await post("/reward/claim", {
    item_id: "dust_red",
    quantity: 1,
    credits: 10,
    source: "authority_smoke"
  });
  assertOk(response, "reward");

  response = await post("/world/resources/sync", {
    resources: [
      { resource_id: "resource_smoke_blue", item_id: "dust_blue", quantity: 1, credits: 3, position: [1, 0, 2] }
    ]
  });
  assertOk(response, "resource sync");

  response = await post("/world/resources/mine", {
    resource: { resource_id: "resource_smoke_blue" }
  });
  assertOk(response, "resource mine");

  response = await post("/reward/claim", {
    claim_id: response.data.claim_id,
    source: "authority_smoke_reserved"
  });
  assertOk(response, "reserved reward claim");

  response = await post("/craft/execute", { recipe_id: "alloy_recipe" });
  assertOk(response, "craft");

  response = await get("/market/listings");
  assertOk(response, "market listings");

  response = await post("/market/order", {
    action: "sell",
    item_id: "bot_scrap",
    quantity: 1,
    unit_price: 12,
    seller: "Smoke Tester"
  });
  assertOk(response, "market sell");

  console.log("[authority-smoke] ok");
}

main().catch((error) => {
  console.error("[authority-smoke] failed:", error instanceof Error ? error.message : error);
  process.exitCode = 1;
});

async function get(pathname) {
  const response = await fetch(`${baseUrl}${pathname}`);
  return response.json();
}

async function post(pathname, payload) {
  const response = await fetch(`${baseUrl}${pathname}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return response.json();
}

function assertOk(response, label) {
  if (!response?.ok) {
    throw new Error(`${label} failed: ${response?.error ?? "unknown error"}`);
  }
}
