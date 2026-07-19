FROM python:3.13-slim AS build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
WORKDIR /src
COPY pyproject.toml .
RUN uv venv /venv && VIRTUAL_ENV=/venv uv pip install -r pyproject.toml

FROM python:3.13-slim
RUN useradd --system --create-home --uid 10001 app
WORKDIR /srv
COPY --from=build /venv /venv
COPY app ./app
COPY schema.sql .
ENV PATH="/venv/bin:$PATH" PYTHONUNBUFFERED=1
USER app
EXPOSE 8000
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
