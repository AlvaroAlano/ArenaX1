from fastapi import FastAPI

app = FastAPI(
    title="API de X1",
    description="Backend para a Plataforma de X1 no Brasil",
    version="1.0.0"
)

@app.get("/")
def read_root():
    return {"message": "API de X1 rodando com sucesso!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
