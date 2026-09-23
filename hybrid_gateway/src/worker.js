const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ status: 'ready', mode: 'hybrid-gateway' });
    }
    if (request.method === 'GET' && url.pathname === '/models') {
      return json({ data: [{ id: 'llama-3.1-8b-instant' }] });
    }
    if (request.method !== 'POST' || url.pathname !== '/chat/completions') {
      return json({ error: 'Not found' }, 404);
    }
    if (!env.GROQ_API_KEY) return json({ error: 'Gateway is not configured' }, 503);

    const ip = request.headers.get('cf-connecting-ip') || 'unknown';
    if (env.ATLAS_RATE_LIMITER) {
      const outcome = await env.ATLAS_RATE_LIMITER.limit({ key: ip });
      if (!outcome.success) return json({ error: 'Rate limit exceeded' }, 429);
    }

    let body;
    try { body = await request.json(); }
    catch (_) { return json({ error: 'Invalid JSON' }, 400); }
    if (!Array.isArray(body.messages) || body.messages.length === 0) {
      return json({ error: 'messages is required' }, 400);
    }

    const upstream = await fetch(GROQ_ENDPOINT, {
      method: 'POST',
      headers: {
        'authorization': `Bearer ${env.GROQ_API_KEY}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama-3.1-8b-instant',
        messages: body.messages,
        temperature: 0.25,
        max_tokens: 256,
        stream: body.stream === true,
        ...(body.response_format ? { response_format: body.response_format } : {}),
      }),
    });
    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        'content-type': upstream.headers.get('content-type') || 'application/json',
        'cache-control': 'no-store',
      },
    });
  },
};

