from pathlib import Path
import cv2
import json
import os
import boto3


PHOTOS_BUCKET = os.getenv("PHOTOS_BUCKET")
QUEUE_URL = os.getenv("QUEUE_URL")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")


def download_photo(key):
    image_path = Path("/function/storage", PHOTOS_BUCKET, key)
    return cv2.imread(image_path)


def detect_faces(image):
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 4)
    return [{"x": int(x), "y": int(y), "w": int(w), "h": int(h)} for (x, y, w, h) in faces]


def send_message(queue_url, message_body):
    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name="ru-central1"
    )
    sqs = session.client(
        "sqs",
        endpoint_url="https://message-queue.api.cloud.yandex.net"
    )
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=message_body
    )


def handler(event, context):
    photo_key = event["messages"][0]["details"]["object_id"]
    
    image = download_photo(photo_key)
    faces = detect_faces(image)

    for face in faces:
        task = {
            "photo_key": photo_key,
            "face": face
        }
        send_message(QUEUE_URL, json.dumps(task))