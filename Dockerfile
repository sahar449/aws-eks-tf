FROM ubuntu:22.04

WORKDIR /app

RUN apt-get update && \
    apt-get install -y python3 python3-pip curl telnet && \
    pip3 install flask && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY app.py /app/

EXPOSE 5000

CMD ["python3", "app.py"]
