#!/usr/bin/env python3
# coding: utf8

from pathlib import Path
import requests
import json
import logging
from random import randrange

from gphotos.authorize import Authorize
from gphotos.restclient import RestClient

log = logging.getLogger()
logging.basicConfig(level=logging.WARNING)
# log.setLevel(logging.NOTSET)


class KindlePhotos:
    def __init__(self):
        self.auth: Authorize = None
        self.provider = "flickr"

    def setup(self):
        if self.provider == "google":
            credentials_file = Path(".gphotos.token")
            secret_file = Path("client_secret.json")
            scope = [
                "https://www.googleapis.com/auth/photoslibrary.readonly",
                "https://www.googleapis.com/auth/photoslibrary.sharing",
            ]
            photos_api_url = (
                "https://photoslibrary.googleapis.com/$discovery" "/rest?version=v1"
            )

            self.album_title = 'Kindle'
            self.auth = Authorize(
                scope, credentials_file, secret_file, 3)

            self.auth.authorize()
            self.google_photos_client = RestClient(
                photos_api_url, self.auth.session)

        elif self.provider == "flickr":
            api_key = u'f8b280fd14aa08758ef060dd232c6573'
            api_secret = u'b8811cd287480495'

            self.flickr = flickrapi.FlickrAPI(
                api_key, api_secret, format='parsed-json')

    def start(self):
        log.debug("Starting up...")

        if self.provider == "google":
            # Get album list
            mylist = self.google_photos_client.sharedAlbums.list.execute(
                pageSize=50).json()

            # Get album ID
            items_count = 0
            for album in mylist['sharedAlbums']:
                if 'title' in album.keys():
                    log.debug('"'+album['title']+'"')
                    if album['title'] == self.album_title:
                        print(album['title'], album['mediaItemsCount'])
                        items_count = int(album['mediaItemsCount'])
                        album_id = album['id']

            if not items_count:
                quit()

            # Get list of images
            body = {
                "pageSize": 50,
                "albumId": album_id,
                # "filters": {
                #     "mediaTypeFilter": {"mediaTypes":  ["PHOTO"]},
                # },
            }
            photo_list = self.google_photos_client.mediaItems.search.execute(
                body).json()
            notfound = 1
            while (notfound):
                idx = randrange(items_count)
                log.debug(idx)
                if photo_list['mediaItems'][idx]['mimeType'] in ["image/jpeg", "image/png"]:
                    notfound = 0
                    media_item = photo_list['mediaItems'][idx]

            # Download photo
            url = str(media_item['baseUrl'])+'=w2048-h1024'
            photo = requests.get(url)

        elif self.provider == "flickr":
            random.seed()
            rand_page = random.randrange(1, 504, 1)
            extras = 'url_sq,url_t,url_s,url_q,url_m,url_n,url_z,url_c,url_l,url_o'

            photos = flickr.photos.search(
                user_id=bhl_id, page=rand_page, per_page=1,
                tag_mode='all', tags='flower,flowers', extras=extras)

            # Get medium sized image
            url = photos['photos']['photo'][0]['url_c']

            with open("photo.jpg", "wb") as f:
                f.write(requests.get(url).content)

        else:
            photo = requests.get("https://source.unsplash.com/random/600x800")

        open('photo.jpg', 'wb').write(photo.content)

    def main(self):
        self.setup()
        self.start()


if __name__ == '__main__':
    KindlePhotos().main()