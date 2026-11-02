"""Parsigo desktop shell — the Windows (and Linux/macOS) window around the
pure-ONNX Persian TTS engine.

``main`` boots a loopback uvicorn server, opens a native WebView2 window with
the existing UI in it, and handles first-run model installation. Everything
that touches the engine lives in ``scripts/`` — this package only replaces the
"open a terminal, start a server, point a browser at it" ritual.
"""

__version__ = "1.1.0"
APP_ID = "Parsigo.PersianTTS.1"
