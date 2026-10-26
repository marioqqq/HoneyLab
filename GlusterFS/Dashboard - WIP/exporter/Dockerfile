FROM python:3.13-slim-bookworm

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends util-linux \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY exporter.py .
COPY collectors ./collectors

EXPOSE 9105
CMD ["python", "exporter.py"]