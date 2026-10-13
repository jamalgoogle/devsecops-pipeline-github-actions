const test = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const { createApp } = require("../src/app");

function request(server, path, { method = "GET", body, raw } = {}) {
  return new Promise((resolve, reject) => {
    const { port } = server.address();
    const data = raw ?? (body ? JSON.stringify(body) : null);
    const headers = data ? { "content-type": "application/json", "content-length": Buffer.byteLength(data) } : {};
    const req = http.request({ port, path, method, headers }, (res) => {
      let text = "";
      res.on("data", (c) => (text += c));
      res.on("end", () => resolve({ status: res.statusCode, headers: res.headers, json: text ? JSON.parse(text) : null }));
    });
    req.on("error", reject);
    if (data) req.write(data);
    req.end();
  });
}

test("payments API", async (t) => {
  const server = createApp().listen(0);
  t.after(() => server.close());

  await t.test("lists products", async () => {
    const res = await request(server, "/api/products");
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.json.length, 3);
  });

  await t.test("creates an order and calculates the total", async () => {
    const res = await request(server, "/api/orders", { method: "POST", body: { productId: 2, quantity: 3 } });
    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.json.total, 103.5);
  });

  await t.test("rejects unknown products", async () => {
    const res = await request(server, "/api/orders", { method: "POST", body: { productId: 99, quantity: 1 } });
    assert.strictEqual(res.status, 400);
  });

  await t.test("rejects out-of-range and non-integer quantities", async () => {
    for (const quantity of [0, 11, 1.5, "3", null]) {
      const res = await request(server, "/api/orders", { method: "POST", body: { productId: 1, quantity } });
      assert.strictEqual(res.status, 400, `quantity ${JSON.stringify(quantity)} should be rejected`);
    }
  });

  await t.test("malformed JSON returns 400 without internals", async () => {
    const res = await request(server, "/api/orders", { method: "POST", raw: "{not json" });
    assert.strictEqual(res.status, 400);
    assert.deepStrictEqual(res.json, { error: "bad request" });
  });

  await t.test("unknown routes return 404", async () => {
    const res = await request(server, "/admin");
    assert.strictEqual(res.status, 404);
  });

  await t.test("security headers are set and framework is not disclosed", async () => {
    const res = await request(server, "/healthz");
    assert.strictEqual(res.headers["x-powered-by"], undefined);
    assert.strictEqual(res.headers["x-content-type-options"], "nosniff");
    assert.ok(res.headers["content-security-policy"]);
    assert.ok(res.headers["strict-transport-security"]);
  });
});
