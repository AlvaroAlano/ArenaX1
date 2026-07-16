import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pix import router as pix_router
from challenges import router as challenges_router
from tournaments import router as tournaments_router
from notifications import router as notifications_router
from admin import router as admin_router
from account import router as account_router
from support import router as support_router
from ratelimit import install_rate_limiting

app = FastAPI(
    title="API de X1",
    description="Backend para a Plataforma de X1 no Brasil",
    version="1.0.0"
)

# Origens liberadas: dev do Vite por padrão, mais o que vier em
# ALLOWED_ORIGINS (lista separada por vírgula) — setar no .env com o domínio
# real antes de ir pra produção. A autenticação é via header Bearer (não usa
# cookies), então allow_credentials fica desligado.
default_origins = "http://localhost:5173,http://127.0.0.1:5173"
allowed_origins = [o.strip() for o in os.getenv("ALLOWED_ORIGINS", default_origins).split(",") if o.strip()]

# Rate limiting: registrado ANTES do CORS de propósito. No Starlette o último
# middleware adicionado é o mais externo, então adicionar o CORS depois garante
# que ele envolva tudo — inclusive uma resposta 429 do rate limiter ganha os
# headers de CORS (senão o browser veria erro de CORS em vez do 429).
install_rate_limiting(app)

# Além da lista fixa, libera qualquer subdomínio *.vercel.app via regex —
# a Vercel gera uma URL nova a cada deploy de preview, então travar só na
# lista fixa quebra CORS a cada preview novo.
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_origin_regex=r"https://.*\.vercel\.app",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registrar os roteadores
app.include_router(pix_router)
app.include_router(challenges_router)
app.include_router(tournaments_router)
app.include_router(notifications_router)
app.include_router(admin_router)
app.include_router(account_router)
app.include_router(support_router)

@app.get("/")
def read_root():
    return {"message": "API de X1 rodando com sucesso!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
