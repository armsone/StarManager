/**
 * iManagerAI gateway for a Cloudflare Worker-compatible runtime.
 * Keep provider API keys and optional IMANAGERAI_APP_TOKEN (legacy: IMANAGER_APP_TOKEN, STARMANAGER_APP_TOKEN) in server secrets.
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        ok: true,
        providers: {
          openAI: Boolean(env.OPENAI_API_KEY),
          gemini: Boolean(env.GEMINI_API_KEY),
        },
      });
    }
    if (request.method !== "POST") {
      return json({ error: "지원하지 않는 요청입니다." }, 405);
    }

    const expectedToken = env.IMANAGERAI_APP_TOKEN || env.IMANAGER_APP_TOKEN || env.STARMANAGER_APP_TOKEN;
    if (expectedToken) {
      const supplied =
        request.headers.get("X-iManagerAI-Token") ||
        request.headers.get("X-iManager-Token") ||
        request.headers.get("X-StarManager-Token");
      if (supplied !== expectedToken) {
        return json({ error: "인증되지 않은 앱 요청입니다." }, 401);
      }
    }

    try {
      if (url.pathname === "/v1/captions") return await createCaption(request, env);
      if (url.pathname === "/v1/images") return await createImage(request, env);
      return json({ error: "요청 경로를 찾지 못했습니다." }, 404);
    } catch (error) {
      return json({ error: error instanceof Error ? error.message : "AI 요청 처리 실패" }, 500);
    }
  },
};

 async function createCaption(request, env) {
  const input = await request.json();
  if (typeof input.prompt !== "string" || !input.prompt.trim()) {
    return json({ error: "생성할 이야기와 작성 지침이 필요합니다." }, 400);
  }
  const provider = normalizeProvider(input.provider);
  if (provider === "gemini") return createGeminiCaption(input, env);
  if (!env.OPENAI_API_KEY) {
    return json({ error: "서버에 OpenAI API 키가 설정되지 않았습니다." }, 503);
  }
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: openAIHeaders(env),
    body: JSON.stringify({
      model: env.OPENAI_TEXT_MODEL || "gpt-5.4",
      input: input.prompt,
      store: false,
    }),
  });
  const payload = await response.json();
  if (!response.ok) return openAIError(payload, response.status);

  const text = payload.output
    ?.flatMap((item) => item.content || [])
    .find((content) => content.type === "output_text")
    ?.text;
  if (!text) return json({ error: "OpenAI 응답에 문구가 없습니다." }, 502);
  return json({ text: text.trim() });
}

async function createGeminiCaption(input, env) {
  if (!env.GEMINI_API_KEY) {
    return json({ error: "서버에 Gemini API 키가 설정되지 않았습니다." }, 503);
  }
  const model = env.GEMINI_TEXT_MODEL || "gemini-3.7-flash";
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: geminiHeaders(env),
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: input.prompt }] }],
    }),
  });
  const payload = await response.json();
  if (!response.ok) return geminiError(payload, response.status);

  const text = payload.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    .trim();
  if (!text) return json({ error: "Gemini 응답에 문구가 없습니다." }, 502);
  return json({ text });
}

async function createImage(request, env) {
  const input = await request.json();
  const vertical = input.aspectRatio !== "square";
  const prompt = [
    "Create one sophisticated Instagram editorial image inspired by the following Korean story.",
    "Express the scene and emotion visually. Do not place text, captions, letters, logos, or watermarks in the image.",
    `Account theme: ${input.accountTopic || "personal story"}`,
    `Voice: ${input.voice || "restrained and warm"}`,
    `Core idea: ${input.sourceIdea}`,
    `Full post: ${input.postText}`,
  ].join("\n");

  if (normalizeProvider(input.provider) === "gemini") {
    return createGeminiImage(prompt, input.aspectRatio, env);
  }
  if (!env.OPENAI_API_KEY) {
    return json({ error: "서버에 OpenAI API 키가 설정되지 않았습니다." }, 503);
  }

  const response = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: openAIHeaders(env),
    body: JSON.stringify({
      model: env.OPENAI_IMAGE_MODEL || "gpt-image-2",
      prompt,
      size: vertical ? "1024x1536" : "1024x1024",
      quality: env.OPENAI_IMAGE_QUALITY || "medium",
      output_format: "png",
      n: 1,
    }),
  });
  const payload = await response.json();
  if (!response.ok) return openAIError(payload, response.status);

  const base64 = payload.data?.[0]?.b64_json;
  if (!base64) return json({ error: "OpenAI 응답에 이미지가 없습니다." }, 502);
  return json({ base64, mimeType: "image/png" });
}

async function createGeminiImage(prompt, aspectRatio, env) {
  if (!env.GEMINI_API_KEY) {
    return json({ error: "서버에 Gemini API 키가 설정되지 않았습니다." }, 503);
  }
  const model = env.GEMINI_IMAGE_MODEL || "gemini-3.1-flash-image";
  const ratio = aspectRatio === "square" ? "1:1" : aspectRatio === "vertical" ? "9:16" : "4:5";
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: geminiHeaders(env),
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: `${prompt}\nAspect ratio: ${ratio}` }] }],
      generationConfig: { responseModalities: ["TEXT", "IMAGE"] },
    }),
  });
  const payload = await response.json();
  if (!response.ok) return geminiError(payload, response.status);

  const image = payload.candidates?.[0]?.content?.parts?.find((part) => part.inlineData?.data);
  if (!image) return json({ error: "Gemini 응답에 이미지가 없습니다." }, 502);
  return json({ base64: image.inlineData.data, mimeType: image.inlineData.mimeType || "image/png" });
}

function openAIHeaders(env) {
  return {
    Authorization: `Bearer ${env.OPENAI_API_KEY}`,
    "Content-Type": "application/json",
  };
}

function geminiHeaders(env) {
  return {
    "x-goog-api-key": env.GEMINI_API_KEY,
    "Content-Type": "application/json",
  };
}

function normalizeProvider(provider) {
  return provider === "gemini" ? "gemini" : "openAI";
}

function openAIError(payload, status) {
  return json({ error: payload?.error?.message || "OpenAI API 요청 실패" }, status);
}

function geminiError(payload, status) {
  return json({ error: payload?.error?.message || "Gemini API 요청 실패" }, status);
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}
