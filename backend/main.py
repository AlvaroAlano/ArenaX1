from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pix import router as pix_router
from challenges import router as challenges_router

app = FastAPI(
    title="API de X1",
    description="Backend para a Plataforma de X1 no Brasil",
    version="1.0.0"
)

# Configuração de CORS para permitir comunicação do Frontend Vue
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Em produção, especificar a URL exata do frontend
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registrar os roteadores
app.include_router(pix_router)
app.include_router(challenges_router)

@app.get("/")
def read_root():
    return {"message": "API de X1 rodando com sucesso!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
