#!/usr/bin/env python3
"""Serve a locally exported Godot Web preview with browser isolation headers."""
import argparse
import functools
import http.server
import os


class PreviewHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="preview")
    parser.add_argument("--port", type=int, default=int(os.environ.get("PORT", "8000")))
    args = parser.parse_args()
    if not os.path.isfile(os.path.join(args.directory, "index.html")):
        parser.error("No index.html in preview directory; export the Web Preview preset first.")
    handler = functools.partial(PreviewHandler, directory=args.directory)
    with http.server.ThreadingHTTPServer(("0.0.0.0", args.port), handler) as server:
        print(f"Serving Godot preview on port {args.port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
