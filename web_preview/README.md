# VELTRIX AI — HTML/CSS design preview

Open `index.html` in a browser for a **responsive** visual preview derived from the reference screenshot. On a desktop the left face panel and right language coaching panel appear side-by-side; phones stack them vertically. The native Android app uses Flutter widgets and a CustomPainter analogue, not this stylesheet.

This preview *can* call the real `gemma3:4b` model via Ollama HTTP when the browser has access and CORS is configured. However Chrome may prevent microphone speech recognition on `file://`, and Ollama rejects arbitrary browser origins by default. For local tests use a simple static server `python -m http.server 8080` and visit `http://localhost:8080/web_preview/` from the project root; permit the page origin in Ollama's `OLLAMA_ORIGINS` and restart Ollama. Do **not** expose Ollama publicly.

The HTML file is intentionally a preview; the **Flutter source is the authoritative APK implementation**.
