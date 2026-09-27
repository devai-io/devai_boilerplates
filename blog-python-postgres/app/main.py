import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, PlainTextResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import auth, db, posts


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await db.create_pool(os.environ["DATABASE_URL"])
    yield
    await app.state.pool.close()


app = FastAPI(title="blog", lifespan=lifespan)
app.include_router(auth.router)
app.include_router(posts.router)


@app.get("/health", response_class=PlainTextResponse)
async def health() -> str:
    return "ok"


# Every error leaves as {"error": "message"}, including framework-raised ones.
@app.exception_handler(StarletteHTTPException)
async def http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    return JSONResponse({"error": str(exc.detail)}, status_code=exc.status_code)


@app.exception_handler(RequestValidationError)
async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
    first = exc.errors()[0]
    if first["loc"][0] == "path":  # a post id that isn't an integer can't name a post
        return JSONResponse({"error": "post not found"}, status_code=404)
    field = ".".join(str(part) for part in first["loc"] if part != "body")
    message = f"{field}: {first['msg']}" if field else first["msg"]
    return JSONResponse({"error": message}, status_code=400)
