---
layout: textpost
title: Setup
---

{% highlight bash %}
cd _site
pygmentize -S default -f html > ../css/pygments.css
{% endhighlight %}

# Getting nokogiri to install on my server and Mac required the following:
gem install 'nokogiri' -v  '1.5.9'
