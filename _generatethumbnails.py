import Image
import ImageOps
import yaml
import os

config = yaml.load(open("_serverconfig.yml", "r"))

dropbox_photos_path = os.path.join(config['dayonepath'], 'photos/')

large_path = "_site/gfx/dayone_large"
thumb_path = "_site/gfx/dayone_thumb"

if not os.path.exists(large_path):
  os.makedirs(large_path)
if not os.path.exists(thumb_path):
  os.makedirs(thumb_path)

print "Generating thumbnails..."

for photo_path in os.listdir(dropbox_photos_path):
  full_photo_path = os.path.join(dropbox_photos_path, photo_path)
  if os.path.isfile(full_photo_path):
    img = Image.open(full_photo_path)

    thumb = ImageOps.fit(img, (100,100), Image.ANTIALIAS)
    thumb.save(os.path.join(thumb_path, photo_path))
    
    if img.size[0] > img.size[1] * 4 or img.size[0] * 4 > img.size[1]:
      img.thumbnail((3000,3000), Image.ANTIALIAS)
      img.save(os.path.join(large_path, photo_path))
    else:
      img.thumbnail((938,938), Image.ANTIALIAS)
      img.save(os.path.join(large_path, photo_path))

print "Done."