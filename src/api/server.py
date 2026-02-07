from fastapi import FastAPI

app = FastAPI(title="Sentinel-X API")


@app.get("/")
def health_check() -> dict:
    return {"status": "ok"}
