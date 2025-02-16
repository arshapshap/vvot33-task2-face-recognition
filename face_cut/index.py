import json
import os
import ydb
from PIL import Image


PHOTOS_BUCKET = os.getenv("PHOTOS_BUCKET")
FACES_BUCKET = os.getenv("FACES_BUCKET")
YDB_URL = os.getenv('YDB_URL')
YDB_DATABASE = os.getenv('YDB_DATABASE')


driver = ydb.Driver(
  endpoint=YDB_URL,
  database=YDB_DATABASE,
  credentials=ydb.iam.MetadataUrlCredentials(),
)
driver.wait(fail_fast=True, timeout=5)
pool = ydb.SessionPool(driver)


def execute_query(query):
    return pool.retry_operation_sync(lambda session: session.transaction().execute(query, commit_tx=True))


def add_face_to_db(face_key):
    execute_query(f"INSERT INTO faces (face_key) VALUES ('{face_key}')")


def download_photo(key):
    return Image.open(f"/function/storage/{PHOTOS_BUCKET}/{key}")


def crop_image(image, face):
    return image.crop((face["x"], face["y"], face["x"] + face["w"], face["y"] + face["h"]))


def handler(event, context):
    message = json.loads(event["messages"][0]["details"]["message"]["body"])
    photo_key = message["photo_key"]
    face = message["face"]

    image = download_photo(photo_key)
    face_image = crop_image(image, face)

    photo_key_without_extension = photo_key.split(".")[0]
    face_key = f"{photo_key_without_extension}_{face["num"]}.jpg"
    face_image.save(f"/function/storage/{FACES_BUCKET}/{face_key}")
    add_face_to_db(face_key)