export default async function handler(req, res) {
  const TARGET = process.env.TENDERLY_RPC || "https://virtual.mainnet.eu.rpc.tenderly.co/6634dcc3-e5ef-48d3-a21b-328a3cfdb6c6";

  try {
    const response = await fetch(TARGET, {
      method: req.method,
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(req.body)
    });

    const text = await response.text();
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Content-Type", "application/json");
    res.status(response.status).send(text);
  } catch (err) {
    res.status(500).json({ error: "Proxy error", message: err.message });
  }
}
