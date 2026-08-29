import assert from "node:assert/strict";
import worker from "./worker.js";

const originalFetch = globalThis.fetch;
globalThis.fetch = async (url) => {
  if (String(url).includes("generativelanguage.googleapis.com")) {
    if (String(url).includes("flash-image")) {
      return new Response(JSON.stringify({
        candidates: [{ content: { parts: [{ inlineData: { data: "Z2VtaW5pLWltYWdl", mimeType: "image/png" } }] } }],
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: "#제미나이 #선택완료\n테스트 문구.\n✨ 다시 걷는다 ✨" }] } }],
    }), { status: 200, headers: { "Content-Type": "application/json" } });
  }
  if (String(url).endsWith("/responses")) {
    return new Response(JSON.stringify({
      output: [{ content: [{ type: "output_text", text: "#새벽바다 #용기기록\n테스트 문구.\n🌙 다시 걷는다 🌙" }] }],
    }), { status: 200, headers: { "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify({ data: [{ b64_json: "aW1hZ2U=" }] }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

const env = {
  OPENAI_API_KEY: "server-only-test-key",
  GEMINI_API_KEY: "server-only-gemini-key",
  IMANAGERAI_APP_TOKEN: "test-token",
};
const headers = { "Content-Type": "application/json", "X-iManagerAI-Token": "test-token" };

const health = await worker.fetch(new Request("https://example.test/health"), env);
assert.equal(health.status, 200);
assert.deepEqual((await health.json()).providers, { openAI: true, gemini: true });

const partialHealth = await worker.fetch(new Request("https://example.test/health"), {
  OPENAI_API_KEY: "server-only-test-key",
});
assert.deepEqual((await partialHealth.json()).providers, { openAI: true, gemini: false });

const caption = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers,
  body: JSON.stringify({ prompt: "test" }),
}), env);
assert.equal(caption.status, 200);
assert.match((await caption.json()).text, /새벽바다/);

const geminiCaption = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers,
  body: JSON.stringify({ provider: "gemini", prompt: "test" }),
}), env);
assert.equal(geminiCaption.status, 200);
assert.match((await geminiCaption.json()).text, /제미나이/);

const image = await worker.fetch(new Request("https://example.test/v1/images", {
  method: "POST",
  headers,
  body: JSON.stringify({ sourceIdea: "새벽 바다", postText: "용기", aspectRatio: "feed" }),
}), env);
assert.equal(image.status, 200);
assert.equal((await image.json()).base64, "aW1hZ2U=");

const geminiImage = await worker.fetch(new Request("https://example.test/v1/images", {
  method: "POST",
  headers,
  body: JSON.stringify({ provider: "gemini", sourceIdea: "새벽 바다", postText: "용기", aspectRatio: "feed" }),
}), env);
assert.equal(geminiImage.status, 200);
assert.equal((await geminiImage.json()).base64, "Z2VtaW5pLWltYWdl");

const legacyIManagerHeaderCaption = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers: { "Content-Type": "application/json", "X-iManager-Token": "test-token" },
  body: JSON.stringify({ prompt: "test" }),
}), env);
assert.equal(legacyIManagerHeaderCaption.status, 200);

const legacyHeaderCaption = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers: { "Content-Type": "application/json", "X-StarManager-Token": "test-token" },
  body: JSON.stringify({ prompt: "test" }),
}), env);
assert.equal(legacyHeaderCaption.status, 200);

const legacyIManagerEnvCaption = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers,
  body: JSON.stringify({ prompt: "test" }),
}), { ...env, IMANAGERAI_APP_TOKEN: undefined, IMANAGER_APP_TOKEN: "test-token" });
assert.equal(legacyIManagerEnvCaption.status, 200);

const legacyEnvCaption = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers,
  body: JSON.stringify({ prompt: "test" }),
}), { ...env, IMANAGERAI_APP_TOKEN: undefined, IMANAGER_APP_TOKEN: undefined, STARMANAGER_APP_TOKEN: "test-token" });
assert.equal(legacyEnvCaption.status, 200);

const unauthorized = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: "{}",
}), env);
assert.equal(unauthorized.status, 401);

const missingPrompt = await worker.fetch(new Request("https://example.test/v1/captions", {
  method: "POST",
  headers,
  body: JSON.stringify({ provider: "openAI", prompt: "" }),
}), env);
assert.equal(missingPrompt.status, 400);

globalThis.fetch = originalFetch;
console.log("BACKEND_CHECK_OK");
