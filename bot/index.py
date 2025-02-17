import os
import json
import requests
import ydb


TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
YDB_URL = os.getenv('YDB_URL')
YDB_DATABASE = os.getenv('YDB_DATABASE')
API_GW_URL = os.getenv("API_GW_URL")


START_MESSAGE = """Используйте команду /getface, чтобы получить фотографию лица без имени. Отправьте в ответ имя, чтобы сохранить его. Используйте /find {name}, чтобы найти фотографию с нужным лицом."""
NO_UNNAMED_FACES_MESSAGE = """Нет неименованных лиц."""
SEND_NAME_MESSAGE = """Выберите имя для этого лица или отправьте команду /cancel, чтобы отменить выбор имени."""
CANCEL_MESSAGE = """Отмена выбора имени."""
UNKNOWN_COMMAND_MESSAGE = """Я принимаю только команды: /getface и /find {name}."""
UNKNOWN_REQUEST_MESSAGE = """Я принимаю только текстовые сообщения."""
USER_STATE_DEFAULT = "DEFAULT"
USER_STATE_SETTING_NAME = "SETTING_NAME"


# database

driver = ydb.Driver(
  endpoint=YDB_URL,
  database=YDB_DATABASE,
  credentials=ydb.iam.MetadataUrlCredentials(),
)
driver.wait(fail_fast=True, timeout=5)
pool = ydb.SessionPool(driver)


def execute_query(query):
    return pool.retry_operation_sync(lambda session: session.transaction().execute(query, commit_tx=True))


def get_user_state(chat_id):
    result = execute_query(f"SELECT state FROM user_states WHERE chat_id = '{chat_id}' LIMIT 1")
    if len(result[0].rows) == 0:
        return USER_STATE_DEFAULT
    return result[0].rows[0].state.decode('utf-8')


def set_user_state(chat_id, state, last_face_key=None):
    execute_query(f"""
        REPLACE INTO user_states (chat_id, state, last_face_key)
        VALUES ('{chat_id}', '{state}', '{last_face_key}')
    """)


def get_last_face(chat_id):
    result = execute_query(f"SELECT last_face_key FROM user_states WHERE chat_id = '{chat_id}' LIMIT 1")
    if len(result[0].rows) == 0:
        return None
    return result[0].rows[0].last_face_key.decode('utf-8')


def get_unnamed_face():
    result = execute_query(f"SELECT face_key FROM faces WHERE name is NULL LIMIT 1")
    if len(result[0].rows) == 0:
        return None
    return result[0].rows[0].face_key.decode('utf-8')


def set_face_name(face_key, name):
    execute_query(f"UPDATE faces SET name = '{name}' WHERE face_key = '{face_key}'")


def find_face(name):
    result = execute_query(f"SELECT photo_key FROM faces WHERE name = '{name}' LIMIT 10")
    if len(result[0].rows) == 0:
        return None
    return list(set([row.photo_key.decode('utf-8') for row in result[0].rows]))


def is_setting_name(chat_id):
    return get_user_state(chat_id) == USER_STATE_SETTING_NAME

# telegram

def send_message(chat_id, message):
    requests.post(f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage?chat_id={chat_id}&text={message}')


def send_photo(chat_id, image_url, caption=""):
    requests.post(f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendPhoto?chat_id={chat_id}&photo={image_url}&caption={caption}')


def get_face_url(face_key):
    return f"{API_GW_URL}?face={face_key}"


def get_photo_url(photo_key):
    return f"{API_GW_URL}?photo={photo_key}"


def start_command(chat_id):
    set_user_state(chat_id, USER_STATE_DEFAULT)
    send_message(chat_id, START_MESSAGE)


def get_face_command(chat_id):
    face_key = get_unnamed_face()
    if not face_key:
        send_message(chat_id, NO_UNNAMED_FACES_MESSAGE)
        return
    set_user_state(chat_id, USER_STATE_SETTING_NAME, face_key)

    face_url = get_face_url(face_key)
    send_photo(chat_id, face_url, caption=SEND_NAME_MESSAGE)


def cancel_command(chat_id):
    set_user_state(chat_id, USER_STATE_DEFAULT)
    send_message(chat_id, CANCEL_MESSAGE)


def find_face_command(chat_id, name):
    photo_keys = find_face(name.lower())
    if len(photo_keys) == 0:
        send_message(chat_id, f"Нет фотографий с \"{name}\".")
    elif len(photo_keys) == 1:
        photo_url = get_photo_url(photo_keys[0])
        send_photo(chat_id, photo_url, caption=f"Найдена одна фотография с \"{name}\".")
    elif len(photo_keys) > 1:
        send_message(chat_id, f"Найдено несколько фотографий с \"{name}\":")
        for photo_key in photo_keys:
            photo_url = get_photo_url(photo_key)
            send_photo(chat_id, photo_url)


def set_name(chat_id, name):
    face_key = get_last_face(chat_id)
    if face_key:
        set_face_name(face_key, name.lower())
        send_message(chat_id, f"Установлено имя: {name}.")
    set_user_state(chat_id, USER_STATE_DEFAULT)


def handle_message(chat_id, message):
    if 'text' in message:
        text = message['text']
        match text:
            case "/start" if not is_setting_name(chat_id):
                start_command(chat_id)
            case "/getface" if not is_setting_name(chat_id):
                get_face_command(chat_id)
            case s if s.startswith('/find ') and not is_setting_name(chat_id):
                find_face_command(chat_id, ' '.join(text.split(' ')[1:]))
            case "/cancel" if is_setting_name(chat_id):
                cancel_command(chat_id)
            case _ if is_setting_name(chat_id):
                set_name(chat_id, text)
            case _:
                send_message(chat_id=chat_id, message=UNKNOWN_COMMAND_MESSAGE)
    else:
        send_message(chat_id=chat_id, message=UNKNOWN_REQUEST_MESSAGE)


def handler(event, context):
    body = json.loads(event['body'])
    message = body.get("message")

    if not message:
        return {"statusCode": 200, "body": "No message"}

    chat_id = message["from"]["id"]
    handle_message(chat_id, message)

    return {
        'statusCode': 200,
        'body': 'OK'
    }