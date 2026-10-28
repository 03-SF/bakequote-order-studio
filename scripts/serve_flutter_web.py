"""Loopback-only Flutter development host; SPA fallback and no URL/token logs."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1] / 'build' / 'web'


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path.startswith('/auth/') or path.startswith('/live/'):
            self.path = '/index.html'
        super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *args):
        pass  # Auth callbacks may contain one-time codes.


if __name__ == '__main__':
    if not (ROOT / 'index.html').exists():
        raise SystemExit('Build Flutter Web first.')
    print('Flutter development host: http://localhost:7357', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 7357), Handler).serve_forever()
