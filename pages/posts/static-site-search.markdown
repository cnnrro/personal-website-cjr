---
title: Adding search to your static site in 6 lines of Nginx (or less!)
meta_title: How to add search to a static website - Post - CJR
description: The easiest, laziest, way to add search to a website using nginx location rules and a redirect to a proper search engine. If it's good enough for John Gruber (Daring Fireball) it's good enough for me.
date: 2020-08-02
code: true
math: false
tags:
  - info
  - tech
...

There are [plenty of ways to add search to a static site](https://gohugo.io/tools/search/):

- For the minimalist we have [lunr.js](https://lunrjs.com/).
- For the maximalist we have [MeiliSearch](https://www.meilisearch.com/).
- For the sell-out we have [Algolia](https://www.algolia.com/).

And, for the lazy we have _this._

---

Now, maybe one day I'll find the energy to stand up a proper search, but for the time being I've decided it'll be easier to lean on an existing search engine. **They've already done all the leg work for me**, so why not just let them to it all?

What we'll do is write a little Nginx that prepends `site:cjr.is` to our reader's search query and redirects the whole thing to a _proper_ search engine--in this case DuckDuckGo.

First, those 6 lines of Nginx I promised:

```nginx
# adding search through nginx
location = /search/ {
	if ($arg_q != "") {
		return 303 https://duckduckgo.com/?q=site%3Acjr.is+$arg_q;
	}
	index /search.html;
}
```

> Note: `%3A` is the [URL encoding](https://en.wikipedia.org/wiki/Percent-encoding) for the character ":". (As it has a special meaning when used in a URL it needs to be encoded, similar to escaping a character.)

Here we declare a location that matches the "/search/" path (including query strings).

If there happens to be a query string with the argument "q" it will prepend our site filter and redirect to a DuckDuckGo with the full query.

If the query string doesn't have that argument, it will display a search page we create "search.html".

Simple.

Now, about this _search box_.

We can add this form anywhere on our site and everything will work as planned.

```html
<form action="https://www.cjr.is/search/" method="get">
	<input name="q" type="text" placeholder="search query">
	<input type="submit" value="Search">
</form>
```

And just like that, **our website has search**.

Now all we need to do is write some content worth searching for.
