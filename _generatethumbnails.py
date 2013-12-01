import Image
import yaml
import os

config = yaml.load(open("_serverconfig.yml", "r"))

dropbox_photos_path = os.path.join(config['dayonepath'], 'photos/')

large_path = "_site/gfx/dayone_large"
thumb_path = "_site/gfx/dayone_thumb"

os.makedirs(large_path)
os.makedirs(thumb_path)

for photo_path in os.listdir(dropbox_photos_path):
  full_photo_path = os.path.join(dropbox_photos_path, photo_path)
  if os.path.isfile(full_photo_path):
    img = Image.open(full_photo_path)
    img.thumbnail((938,938), Image.ANTIALIAS)
    img.save(os.path.join(large_path, photo_path))
    
    # TODO: Use ImageOps to create square thumbnails.
    # http://stackoverflow.com/questions/1386352/pil-thumbnail-and-end-up-with-a-square-image
    img = Image.open(full_photo_path)
    img.thumbnail((100,100), Image.ANTIALIAS)
    img.save(os.path.join(thumb_path, photo_path))
