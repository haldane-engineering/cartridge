import http.client
import httplib2
import os
import sys
import time
import random
import json
import contextlib

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

BIN_DIR = os.path.dirname(os.path.abspath(__file__))

class YoutubeUploaderService:
    MAX_RETRIES = 10
    RETRIABLE_EXCEPTIONS = (
        httplib2.HttpLib2Error, IOError, http.client.NotConnected,
        http.client.IncompleteRead, http.client.ImproperConnectionState,
        http.client.CannotSendRequest, http.client.CannotSendHeader,
        http.client.ResponseNotReady, http.client.BadStatusLine
    )
    RETRIABLE_STATUS_CODES = (500, 502, 503, 504)
    CLIENT_SECRETS_FILE = os.environ.get('YOUTUBE_CLIENT_SECRETS', os.path.join(BIN_DIR, 'client_secrets.json'))
    TOKEN_FILE = os.environ.get('YOUTUBE_TOKEN_FILE', os.path.join(BIN_DIR, 'youtube_token.json'))
    YOUTUBE_UPLOAD_SCOPE = 'https://www.googleapis.com/auth/youtube.upload'
    YOUTUBE_API_SERVICE_NAME = 'youtube'
    YOUTUBE_API_VERSION = 'v3'
    MISSING_CLIENT_SECRETS_MESSAGE = """
        WARNING: Please configure OAuth 2.0

        To make this sample run you will need to populate the client_secrets.json file
        found at

        %s

        with information from the API Console
        https://console.cloud.google.com/

        For more information about the client_secrets.json file format, please visit:
        https://developers.google.com/api-client-library/python/guide/aaa_client_secrets
    """ % CLIENT_SECRETS_FILE
    VALID_PRIVACY_STATUSES = ("public", "private", "unlisted")
    SPORTS_CATEGORY_ID = "17"

    def __init__(self, params):
        # set up
        httplib2.RETRIES = 1
        self.__opts = json.loads(params)

    def initialize_upload(self):
        youtube = self.__get_authenticated_service()
        body = self.__build_upload_body(self.__opts)
        insert_request = youtube.videos().insert(
            part=",".join(body.keys()),
            body=body,
            media_body=MediaFileUpload(self.__opts['file_path'], chunksize=-1, resumable=True)
        )
        video_id = self.resumable_upload(insert_request)
        thumbnail_path = self.__opts.get('thumbnail_path')
        if thumbnail_path and os.path.exists(thumbnail_path):
            self.__set_thumbnail(youtube, video_id, thumbnail_path)
        return video_id

    def resumable_upload(self, insert_request):
        response = None
        error = None
        retry = 0
        while response is None:
            try:
                _, response = insert_request.next_chunk()
                if response is not None and 'id' not in response:
                    sys.exit(f'Upload failed with an unexpected response {response}')
            except HttpError as e:
                if e.resp.status in self.RETRIABLE_STATUS_CODES:
                    error = f"A retriable HTTP error {e.resp.status} occurred: {e.content}"
                else:
                    raise
            except self.RETRIABLE_EXCEPTIONS as e:
                error = f"A retriable error occurred: {e}"
            if error is not None:
                retry += 1
                if retry > self.MAX_RETRIES:
                    sys.exit(f'Upload failed after {self.MAX_RETRIES} retries: {error}')
                max_sleep = 2 ** retry
                sleep_seconds = random.random() * max_sleep
                time.sleep(sleep_seconds)
                error = None
        return response['id']

    def __set_thumbnail(self, youtube, video_id, thumbnail_path):
        # the video is already live at this point, so a failed thumbnail shouldn't fail the upload
        # (403 here usually means the channel isn't verified for custom thumbnails)
        try:
            youtube.thumbnails().set(
                videoId=video_id,
                media_body=MediaFileUpload(thumbnail_path, mimetype='image/jpeg')
            ).execute()
        except HttpError as e:
            print(f"Failed to set thumbnail for {video_id}: {e.resp.status} {e.content}", file=sys.stderr)

    def __get_authenticated_service(self):
        credentials = None
        if os.path.exists(self.TOKEN_FILE):
            credentials = Credentials.from_authorized_user_file(self.TOKEN_FILE, [self.YOUTUBE_UPLOAD_SCOPE])
        if credentials and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
            self.__save_credentials(credentials)
        if not credentials or not credentials.valid:
            # first-time setup only: opens a browser for consent, so run this locally, not from a worker
            if not os.path.exists(self.CLIENT_SECRETS_FILE):
                sys.exit(self.MISSING_CLIENT_SECRETS_MESSAGE)
            flow = InstalledAppFlow.from_client_secrets_file(
                self.CLIENT_SECRETS_FILE,
                scopes=[self.YOUTUBE_UPLOAD_SCOPE]
            )
            # the consent prompt goes to stdout by default; keep stdout reserved for the video url
            with contextlib.redirect_stdout(sys.stderr):
                credentials = flow.run_local_server(port=8080)
            self.__save_credentials(credentials)
        if not credentials or not credentials.valid:
            sys.exit('Unable to obtain valid YouTube credentials')
        return build(self.YOUTUBE_API_SERVICE_NAME, self.YOUTUBE_API_VERSION, credentials=credentials)

    def __save_credentials(self, credentials):
        with open(self.TOKEN_FILE, 'w') as token:
            token.write(credentials.to_json())

    def __build_upload_body(self, opts):
        keywords = opts.get('keywords') or []
        if isinstance(keywords, str):
            keywords = [k.strip() for k in keywords.split(',') if k.strip()]
        privacy_status = opts.get('privacy_status') or self.VALID_PRIVACY_STATUSES[0]
        if privacy_status not in self.VALID_PRIVACY_STATUSES:
            sys.exit(f'Invalid privacy status {privacy_status}')

        snippet = {
            "title": opts['title'],
            "description": opts.get('description') or '',
            "categoryId": str(opts.get('category') or self.SPORTS_CATEGORY_ID),
        }
        if keywords:
            snippet["tags"] = keywords
        return {
            "snippet": snippet,
            "status": {
                "privacyStatus": privacy_status,
                "selfDeclaredMadeForKids": False,
            }
        }

if __name__ == "__main__":
    video_id = YoutubeUploaderService(sys.stdin.read()).initialize_upload()
    print(f"https://www.youtube.com/watch?v={video_id}")
