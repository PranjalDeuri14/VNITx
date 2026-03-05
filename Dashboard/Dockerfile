FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Dashboard/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY Dashboard/ /app/
COPY screen_capture_component/ /app/screen_capture_component/

ENV PYTHONUNBUFFERED=1

CMD ["sh", "-c", "streamlit run app.py --server.port ${PORT:-8501} --server.address 0.0.0.0"]
