import Image
import ImageOps
import yaml
import time
import os

config = yaml.load(open("_serverconfig.yml", "r"))

dropbox_photos_path = os.path.join(config['dayonepath'], 'photos/')

large_path = "_site/gfx/dayone_large"
thumb_path = "_site/gfx/dayone_thumb"
last_generated_path = ".lastgen"

if not os.path.exists(large_path):
  os.makedirs(large_path)
if not os.path.exists(thumb_path):
  os.makedirs(thumb_path)

print "Generating thumbnails..."

if os.path.isfile(last_generated_path):
  lastgentime = os.path.getmtime(last_generated_path)
else:
  lastgentime = 0

for photo_path in os.listdir(dropbox_photos_path):
  full_photo_path = os.path.join(dropbox_photos_path, photo_path)
  if os.path.isfile(full_photo_path) and os.path.getmtime(full_photo_path) > lastgentime:
    print full_photo_path
    img = Image.open(full_photo_path)

    thumb = ImageOps.fit(img, (100,100), Image.ANTIALIAS)
    thumb.save(os.path.join(thumb_path, photo_path))
    
    if img.size[0] > img.size[1] * 4 or img.size[0] * 4 < img.size[1]:
      img.thumbnail((3000,3000), Image.ANTIALIAS)
      img.save(os.path.join(large_path, photo_path))
    else:
      img.thumbnail((938,938), Image.ANTIALIAS)
      img.save(os.path.join(large_path, photo_path))

# Touch the lastmodified file
with open(last_generated_path, 'a'):
  os.utime(last_generated_path, None)

print "Done."
