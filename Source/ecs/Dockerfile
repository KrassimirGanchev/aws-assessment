FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY dispatch_task.py .

CMD ["python", "dispatch_task.py"]
