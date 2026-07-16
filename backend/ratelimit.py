"""Rate limiting leve, in-memory, sem dependência externa.

Motivação (gap de go-live): nenhuma rota tinha proteção contra flood. Como todo
endpoint de negócio exige JWT, o abuso já fica limitado à própria conta — então
isto é defesa em profundidade, não a única barreira. Cobre dois riscos práticos:
um script malicioso (ou bug de client) martelando um endpoint, e scraping das
rotas públicas de listagem.

Design: janela fixa por (IP, balde), dois baldes — 'sensitive' (POSTs que mexem
em dinheiro) mais apertado, 'general' (resto) generoso. Webhook do Mercado Pago
e preflight CORS (OPTIONS) ficam de fora. Chave = IP do cliente via
X-Forwarded-For (o Render põe o IP real do cliente ali), com fallback.

Render free roda 1 instância, então o dicionário em memória é suficiente. Se um
dia escalar pra N instâncias, cada uma aplica o limite localmente (fica N× mais
frouxo, mas nunca deixa de existir) — trocar por Redis seria o próximo passo.
"""
import os
import threading
import time

from fastapi.responses import JSONResponse

RATE_LIMIT_ENABLED = os.getenv("RATE_LIMIT_ENABLED", "true").lower() not in ("false", "0", "no")
WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW", "60"))
GENERAL_LIMIT = int(os.getenv("RATE_LIMIT_GENERAL", "240"))     # req/janela por IP
SENSITIVE_LIMIT = int(os.getenv("RATE_LIMIT_SENSITIVE", "30"))  # req/janela por IP

# POSTs que criam movimento de dinheiro — balde apertado.
_SENSITIVE_POST_PATHS = {
    "/api/pix/deposit",
    "/api/pix/withdraw",
    "/api/pix/dev/simulate-deposit",
    "/api/challenges/create",
    "/api/tournaments/create",
    "/api/tournaments/online/create",
    "/api/tournaments/online/join",
}

# Server-to-server, autenticado por HMAC próprio — nunca limitar.
_EXEMPT_PATHS = {"/api/pix/webhook"}

_buckets: dict = {}          # (ip, balde) -> [inicio_janela, contagem]
_lock = threading.Lock()
_checks_since_sweep = 0


def _client_key(request) -> str:
    xff = request.headers.get("x-forwarded-for")
    if xff:
        first = xff.split(",")[0].strip()
        if first:
            return first
    return request.client.host if request.client else "unknown"


def _rule_for(request):
    """Devolve (balde, limite) ou None se a rota é isenta."""
    path = request.url.path
    if request.method == "OPTIONS" or path in _EXEMPT_PATHS:
        return None
    if request.method == "POST" and path in _SENSITIVE_POST_PATHS:
        return ("sensitive", SENSITIVE_LIMIT)
    return ("general", GENERAL_LIMIT)


def _sweep(now: float):
    """Remove janelas velhas pra o dicionário não crescer sem limite."""
    stale = [k for k, v in _buckets.items() if now - v[0] >= WINDOW_SECONDS]
    for k in stale:
        _buckets.pop(k, None)


def _check(key, limit: int):
    """(permitido, retry_after_segundos). Janela fixa, thread-safe."""
    global _checks_since_sweep
    now = time.time()
    with _lock:
        _checks_since_sweep += 1
        if _checks_since_sweep >= 2000:
            _checks_since_sweep = 0
            _sweep(now)

        entry = _buckets.get(key)
        if entry is None or now - entry[0] >= WINDOW_SECONDS:
            _buckets[key] = [now, 1]
            return True, 0
        entry[1] += 1
        if entry[1] > limit:
            return False, int(WINDOW_SECONDS - (now - entry[0])) + 1
        return True, 0


def install_rate_limiting(app):
    """Registra o middleware no app FastAPI. No-op se desligado por env."""
    if not RATE_LIMIT_ENABLED:
        return

    @app.middleware("http")
    async def _rate_limit_middleware(request, call_next):
        rule = _rule_for(request)
        if rule is not None:
            bucket, limit = rule
            allowed, retry_after = _check((_client_key(request), bucket), limit)
            if not allowed:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Muitas requisições em pouco tempo. Aguarde um instante e tente de novo."},
                    headers={"Retry-After": str(retry_after)},
                )
        return await call_next(request)
