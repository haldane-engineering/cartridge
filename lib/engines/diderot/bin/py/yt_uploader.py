import httplib
import httplib2
import os
import time
import random
import argparse

from apiclient.discovery import build
from apiclient.errors import HttpError
from apiclient.http import MediaFileUpload
from google_auth_oauthlib.flow import InstalledAppFlow
# from oauth2client.client import flow_from_clientsecrets

class YoutubeUploaderService:
    MAX_RETRIES = 10
    RETRIABLE_EXCEPTIONS = (
        httplib2.HttpLib2Error, IOError, httplib.NotConnected,
        httplib.IncompleteRead, httplib.ImproperConnectionState,
        httplib.CannotSendRequest, httplib.CannotSendHeader,
        httplib.ResponseNotReady, httplib.BadStatusLine
    )
    RETRIABLE_STATUS_CODES = (500, 502, 503, 504)
    CLIENT_SECRETS_FILE = 'client_secrets.json'
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
    """ % os.path.abspath(os.path.join(os.path.dirname(__file__), CLIENT_SECRETS_FILE))
    VALID_PRIVACY_STATUSES = ("public","private", "unlisted")

    def __init__(self):
        # set up
        httplib2.RETRIES = 1
        self.__opts = self.__parse_args()
    
 
    
    def initialize_upload(self):
        youtube = self.__get_authenticated_service()
        body = self.__build_upload_body(self.__opts)
        insert_request = youtube.videos().insert(
            part=",".join(body.keys()),
            body=body,
            media_body=MediaFileUpload(self.__opts.file, chunksize=-1)
        )
        self.resumable_upload(insert_request)
    
    def resumable_upload(self, insert_request):
        response = None
        error = None
        retry = 0
        while response is None:
            try:
                _, response = insert_request.next_chunk()
                if response is not None:
                    if 'id' not in response:
                        exit(f'Upload failed with an unexpected response {response}')
            except (HttpError, e):
                if e.resp.status in self.RETRIABLE_STATUS_CODES:
                    pass
                else: 
                    raise
            except self.RETRIABLE_EXCEPTIONS:
                error = "Exception occurred: %s" % e
            if error is not None:
                retry += 1
                if retry > self.MAX_RETRIES:
                    exit()
                max_sleep = 2 ** retry
                sleep_seconds = random.random() * max_sleep
                time.sleep(sleep_seconds)
    
    def __get_authenticated_service(self):
        flow = InstalledAppFlow.from_client_secrets_file(
            'client_secrets.json', 
            scopes=[self.YOUTUBE_UPLOAD_SCOPE]
        )
        flow.run_local_server()
        credentials = flow.credentials()
        if credentials is not None and credentials.valid:
            return build(self.YOUTUBE_API_SERVICE_NAME, self.YOUTUBE_API_VERSION, 
                         http=credentials.authorize(httplib2.Http()))
        else:
            return None          
    
    def __build_upload_body(self, opts):
        return {
            "snippet": { 
                "title": opts.title,
                "description": opts.description, 
                "tags": opts.keywords.split(",") if opts.keywords is not None else None, 
                "categoryId": opts.category
                },
            "status": { "privacyStatus": opts.privacyStatus }
        }
    
    def __parse_args(self):
        parser = argparse.ArgumentParser()
        parser.add_argument("--file", required=True, help="Video file to upload")
        parser.add_argument("--title", help="Video title", default="Test Title")
        parser.add_argument("--description", help="Video description",
                            default="Test Description")
        parser.add_argument("--category", default="22",
                            help="Numeric video category. " +
                                 "See https://developers.google.com/youtube/v3/docs/videoCategories/list")
        parser.add_argument("--keywords", help="Video keywords, comma separated",
                            default="")
        parser.add_argument("--privacyStatus", choices=self.VALID_PRIVACY_STATUSES,
                            default=self.VALID_PRIVACY_STATUSES[0], help="Video privacy status.")
        return parser.parse_args()
        



if __name__ == "__main__":
    uploader = YoutubeUploaderService()
    try:
        uploader.initialize_upload()
    except(HttpError):
        raise


                                                                       