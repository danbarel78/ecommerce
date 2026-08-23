# Multi-stage build — slim runtime, non-root user.
FROM python:3.12-slim AS builder

WORKDIR /app
ENV VIRTUAL_ENV=/opt/venv
RUN python -m venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip install --no-cache-dir --upgrade pip
COPY pyproject.toml README.md ./
COPY src ./src
# Install into an isolated venv so every dependency (incl. transitives) is captured.
RUN pip install --no-cache-dir .

FROM python:3.12-slim AS runtime

# Non-root runtime user.
RUN groupadd --system app && useradd --system --gid app --home /app appuser
WORKDIR /app

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
COPY --from=builder /opt/venv /opt/venv

USER appuser
EXPOSE 8000

# Uvicorn ASGI server. Tune workers via the platform (HPA scales pods, not workers).
CMD ["uvicorn", "product_service.main:app", "--host", "0.0.0.0", "--port", "8000"]
