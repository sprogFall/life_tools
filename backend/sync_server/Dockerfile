FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir -r /app/requirements.txt

COPY sync_server /app/sync_server

RUN mkdir -p /data
ENV SYNC_SERVER_DB_PATH=/data/sync.db

EXPOSE 8080

CMD ["uvicorn", "sync_server.main:app", "--host", "0.0.0.0", "--port", "8080"]

