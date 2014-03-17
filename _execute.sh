jekyll build --trace
cd _site
pygmentize -S default -f html > ../css/pygments.css
cd ..
python _generatethumbnails.py
cd _site
statify .

