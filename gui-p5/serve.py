"""Read-only local server for the p5 Workbench.

Static GUI files are served on :8080. GET /runtime/* is proxied to the existing
Runtime bridge on 127.0.0.1:8765 so the browser stays same-origin.
POST/PUT/PATCH/DELETE are intentionally not proxied.
"""
from __future__ import annotations

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
            body = ('{"error":"runtime_unreachable","detail":' + repr(str(exc.reason)).replace("'", '"') + '}').encode('utf-8')
            status = 502
            content_type = 'application/json; charset=utf-8'

        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

if __name__ == '__main__':
    server = ThreadingHTTPServer((HOST, PORT), WorkbenchHandler)
    print(f'RDL p5 Workbench: http://{HOST}:{PORT}')
    print(f'Read-only proxy: /runtime/* -> {RUNTIME}')
    server.serve_forever()