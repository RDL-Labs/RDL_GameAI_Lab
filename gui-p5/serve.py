"""Read-only local server for the p5 Workbench.

Static GUI files are served on :8080. GET /runtime/* is proxied to the existing
Runtime bridge on 127.0.0.1:8765 so the browser stays same-origin.
POST/PUT/PATCH/DELETE are intentionally not proxied.
"""
from __future__ import annotations

import json
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

GUI_DIR = Path(__file__).resolve().parent
HOST = '127.0.0.1'
PORT = 8080
RUNTIME = 'http://127.0.0.1:8765'

class WorkbenchHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(GUI_DIR), **kwargs)

    def do_GET(self):
        if self.path.startswith('/runtime/'):
            return self._proxy_runtime_get()
        return super().do_GET()

    def do_POST(self):
        self.send_error(405, 'Workbench proxy is read-only')

    do_PUT = do_POST
    do_PATCH = do_POST
    do_DELETE = do_POST

    def _proxy_runtime_get(self):
        runtime_path = self.path[len('/runtime'):]
        request = Request(RUNTIME + runtime_path, method='GET')
        try:
            with urlopen(request, timeout=2.0) as response:
                body = response.read()
                status = response.status
                content_type = response.headers.get('Content-Type', 'application/json; charset=utf-8')
        except HTTPError as exc:
            body = exc.read()
            status = exc.code
            content_type = exc.headers.get('Content-Type', 'application/json; charset=utf-8')
        except URLError as exc:
            body = json.dumps({"error": "runtime_unreachable", "detail": str(exc.reason)}, ensure_ascii=False).encode('utf-8')
            status = 502
            content_type = 'application/json; charset=utf-8'

        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

if __name__ == '__main__':
    import argparse
    import webbrowser
    import threading

    parser = argparse.ArgumentParser(description='RDL p5 Workbench Server')
    parser.add_argument('--no-browser', action='store_true', help='Do not open browser automatically')
    parser.add_argument('--port', type=int, default=PORT, help=f'Port to listen on (default: {PORT})')
    args = parser.parse_args()

    port = args.port
    server = ThreadingHTTPServer((HOST, port), WorkbenchHandler)
    url = f'http://{HOST}:{port}'
    print('=====================================================')
    print(f' RDL GameAI Workbench: {url}')
    print(f' Read-only Runtime Proxy: /runtime/* -> {RUNTIME}')
    print('=====================================================')
    print('Press Ctrl+C to stop.')

    if not args.no_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nWorkbench stopped cleanly.')