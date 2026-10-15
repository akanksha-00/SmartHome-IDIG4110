FROM ghcr.io/astral-sh/uv:python3.14-bookworm

WORKDIR /app

COPY pyproject.toml uv.lock README.md ./
COPY src ./src

RUN uv sync --frozen --no-dev

COPY . .

# Create a dedicated, unprivileged application user.
RUN groupadd --system --gid 10001 smarthome \
    && useradd --system \
        --uid 10001 \
        --gid smarthome \
        --home-dir /home/smarthome \
        --create-home \
        smarthome \
    && mkdir -p /app/logs \
    && chown -R smarthome:smarthome /app

# Run the application without root privileges.
USER smarthome

EXPOSE 8000

CMD ["uv", "run", "uvicorn", "smarthome_api.main:app", "--host", "0.0.0.0", "--port", "8000"]