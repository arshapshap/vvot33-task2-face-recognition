import base64
from io import BytesIO
import os
from PIL import Image

FACES_BUCKET = os.getenv("FACES_BUCKET")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")

def download_photo(key):
    return Image.open(f"/function/storage/{FACES_BUCKET}/{key}")

def handler(event, context):
    face_key = event.get("queryStringParameters", {}).get("face")

    if not face_key:
        return {
            "statusCode": 400,
            "body": "Missing 'face' parameter"
        }

    image = download_photo(face_key)
    buffered = BytesIO()
    image.save(buffered, format="JPEG")
    image_base64 = base64.b64encode(buffered.getvalue()).decode('utf-8')

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "image/jpeg"
        },
        "body": image_base64,
        "isBase64Encoded": True
    }