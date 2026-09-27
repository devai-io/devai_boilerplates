FROM python:3.14-slim AS build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
ENV UV_PROJECT_ENVIRONMENT=/venv UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never
WORKDIR /src
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

FROM python:3.14-slim
RUN useradd --system --uid 10001 app
WORKDIR /srv
COPY --from=build /venv /venv
COPY schema.sql ./
COPY app ./app
ENV PATH="/venv/bin:$PATH" PYTHONUNBUFFERED=1
USER app
EXPOSE 8080
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
