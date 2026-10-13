const { createApp } = require("./app");

const PORT = process.env.PORT || 8080;
const server = createApp().listen(PORT, () => {
  console.log(`novacart-payments-api listening on ${PORT}`);
});

process.on("SIGTERM", () => server.close(() => process.exit(0)));
