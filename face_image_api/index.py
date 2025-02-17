import base64
from io import BytesIO
import os
from PIL import Image

FACES_BUCKET = os.getenv("FACES_BUCKET")
PHOTOS_BUCKET = os.getenv("PHOTOS_BUCKET")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")

def download_face(key):
    return Image.open(f"/function/storage/{FACES_BUCKET}/{key}")

def download_photo(key):
    return Image.open(f"/function/storage/{PHOTOS_BUCKET}/{key}")

def handler(event, context):
    face_key = event.get("queryStringParameters", {}).get("face")
    photo_key = event.get("queryStringParameters", {}).get("photo")

    if face_key:
        image = download_face(face_key)
    elif photo_key:
        image = download_photo(photo_key)
    else:
        return {
            "statusCode": 400,
            "body": "Missing 'face' or 'photo' parameter"
        }

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