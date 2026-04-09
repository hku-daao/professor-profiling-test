FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1

# Required at runtime (no defaults): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
# Copy backend/.env.example to .env locally or set these in your host/orchestrator.

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Do not run sync on container start. Run sync manually, e.g. Railway: one-off job / cron, or
# `railway run python -m app.sync` from a machine with the Railway CLI linked to this service.
CMD ["sleep", "infinity"]
