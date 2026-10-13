const express = require("express");
const helmet = require("helmet");

const PRODUCTS = [
  { id: 1, name: "Wireless Keyboard", price: 49.9 },
  { id: 2, name: "USB-C Hub", price: 34.5 },
  { id: 3, name: "27-inch Monitor", price: 219.0 },
];

const MAX_QUANTITY = 10;

function createApp() {
  const app = express();

  app.disable("x-powered-by");
  app.use(helmet());
  app.use(express.json({ limit: "10kb" }));

  app.get("/healthz", (_req, res) => res.json({ status: "ok" }));

  app.get("/api/products", (_req, res) => res.json(PRODUCTS));

  // Input is validated before use: only known product ids and bounded integer quantities
  app.post("/api/orders", (req, res) => {
    const { productId, quantity } = req.body || {};
    const product = PRODUCTS.find((p) => p.id === productId);

    if (!product) {
      return res.status(400).json({ error: "unknown productId" });
    }
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > MAX_QUANTITY) {
      return res.status(400).json({ error: `quantity must be an integer between 1 and ${MAX_QUANTITY}` });
    }

    return res.status(201).json({
      productId: product.id,
      quantity,
      total: Number((product.price * quantity).toFixed(2)),
    });
  });

  app.use((_req, res) => res.status(404).json({ error: "not found" }));

  // Never leak stack traces or internal messages to clients
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    const status = err.status && err.status < 500 ? err.status : 500;
    res.status(status).json({ error: status < 500 ? "bad request" : "internal server error" });
  });

  return app;
}

module.exports = { createApp };
