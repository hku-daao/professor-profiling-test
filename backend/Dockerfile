FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1

# Required at runtime (no defaults): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
# Copy backend/.env.example to .env locally or set these in your host/orchestrator.

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

CMD ["python", "-m", "app.sync"]
