jekyll build --trace
cd _site
pygmentize -S default -f html > ../css/pygments.css
ln -s /Users/featherless/ServerDropbox/Dropbox/Apps/Day\ One/Journal.dayone/photos /Users/featherless/www/blog/_site/gfx/dayone
cd ..
python _generatethumbnails.py
ln -s /Users/featherless/www/blog/.thumbs/dayone_large /Users/featherless/www/blog/_site/gfx/dayone_large
ln -s /Users/featherless/www/blog/.thumbs/dayone_thumb /Users/featherless/www/blog/_site/gfx/dayone_thumb
cd _site
statify .

