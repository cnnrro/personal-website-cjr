# TODO:
# - Find some way that makes sense for sass > css conversion, and minification pipelines for resulting css and other images
# - Seperate a "max" folder that is all files after compilation but before minification?
# - Replicate hugo's list pages (_index.markdown that gets access to a .pages variable)
# - Should /pages/contact.markdown -> _public/contact/index.html ?
# - How to generate rss/atom? Anyway to generate filenames from the template file ending? Seems unlikely
#	 - Probably just need to make a special case, not everything needs to be abstracted away
# - pages currently don't depend on their templates and partials... Not even sure this can be done in a makefile cleanly
# - Add variables for all the common folders (eg. $(OUTPUT_FOLDER) defaults to "_public" but can be changed. Useful for github pages.)

# NOTE:
# - https://stackoverflow.com/questions/53026696/makefile-multiple-targets-in-sub-directories

# ---------- VARIABLES ------------------------------------
# TODO: Can these be defined later where they are more relevant?

pages ::= $(filter-out $(subst _index.markdown,index.markdown,$(shell find pages/ -type f -name '_index.markdown' -printf '%P\n')),$(shell find pages/ -type f \( -name '*.markdown' -and -not -name '_index.markdown' \) -printf '%P\n'))
# DONE: ignore index.markdown if a _index.markdown file also exists
yaml ::= $(patsubst %.markdown, %.yaml, $(addprefix .build/yaml/, $(pages)))
list_yaml ::= $(addprefix .build/yaml/, $(subst _index.markdown,index.yaml,$(shell find pages/ -type f -name '_index.markdown' -printf '%P\n')))

all_pages ::= $(shell find pages -type f -printf '%P\n' | sed -e 's/_index.markdown/index.markdown/g' | sort | uniq) # sort uniq used to avoid duplication in overloaded index cases
max_html ::= $(patsubst %.markdown, %.html, $(addprefix .build/html/,$(all_pages)))
# DONE: include list_yamls in max_html
html ::= $(patsubst %.markdown, %.html, $(addprefix _public/,$(all_pages)))

minifyable ::= $(addprefix _public/, $(shell find static/ -type f -printf '%P\n' | grep -iE '\.(html|css|json|xml|js)$$'))
optimizable ::= $(addprefix _public/, $(shell find static/ -type f -printf '%P\n' | grep -iE '\.(jpg|jpeg|png|gif|svg)$$'))
sassable ::= $(patsubst %.scss, %.css, $(addprefix _public/, $(shell find static/ -type f -printf '%P\n' | grep -iE '/[^_].*\.scss$$')))
# only when the filename doesn't start with _
# eg. style.scss yes
# eg. _compnent.scss no
the_rest ::= $(addprefix _public/, $(shell find static/ -type f -printf '%P\n' | grep -iEv '\.(html|css|json|xml|js|scss|jpg|jpeg|png|gif|svg)$$'))

# ---------- PHONIES --------------------------------------
.PHONY: all multi watch test deploy clean
all: $(yaml) $(list_yaml) $(max_html) $(html) $(the_rest) $(minifyable) $(optimizable)

# for running jobs in parallel
multi:
	$(MAKE) -j4 all

watch:
	./helper-functions/watch

test:
	devd -l _public/ cdn=_public/

# TODO: add rclone to backblaze b2 bucket for cdn fallback if ever needed
# TODO: configure ssh server and pull this dynamically (maybe an override or env?)
deploy:
	rsync --recursive _public/ vps:/srv/www.cjr.is/ --cvs-exclude --exclude=/.well-known --delete --delete-after

clean:
	rm -f $(yaml) $(list_yaml) $(max_html) $(html) $(minifyable) $(optimizable) $(the_rest)

# .PHONY: testing
# testing: $(list_yaml)


# ---------- PAGES ----------------------------------------
# TODO: Should we allow other files to be placed in the content directory that will work like static/
# TODO: Should we even have static/ at all and instead just treat pages/ as a pure source directory? Perhaps rename it?

# Pages are markdown files placed within the pages/ directory.
# Each .markdown file represents and equivalent html file to be generated in its place.
# Eg. pages/posts/index.markdown -> _public/posts/index.html

# Pages are first turned into yaml files which contain all the data required for templating
# 1. mkdir the containing folder just in case
# 2. use the site-config.yaml as a base (to be overwritten by more specific data)
# 3. read the front matter from the page and override any site-config defaults
# 4. pandoc the page to retrieve html content, overwrite the pages yaml with this html content

# NOTE:
# `pandoc -f markdown-smart` disables smart quotes and dashes (format: markdown, extension: -smart (to remove the smart typography extension))

$(yaml): .build/yaml/%.yaml: pages/%.markdown config/site-config.yaml config/filters.lua
	mkdir -p $(dir $@)
	yq read config/site-config.yaml > $@
	sed '/\.\.\./q' $< | yq read - | yq merge --inplace --overwrite $@ -
	yq new 'content' "`pandoc -f markdown --wrap=none --lua-filter config/filters.lua $<`" | yq merge --inplace --overwrite $@ -
	yq new 'permalink' "`yq read $@ 'baseurl'``echo '$<' | sed -e 's/^pages\///g' -e 's/index.markdown$$//g' -e 's/.markdown$$/\//g'`" | yq merge --inplace --overwrite $@ -

# Generate list pages yaml that is dependant on all the yaml within subfolders
# TODO: decide: should all subfolder files be included in .pages? or should it be all same directory files and only subfolder files if the file name is index.yaml?
.SECONDEXPANSION:
$(list_yaml): .build/yaml/%index.yaml: pages/%_index.markdown config/site-config.yaml config/filters.lua $$(shell find pages/$$* -type f -not -name index.markdown -and -not -name _index.markdown | sed -e 's/^pages/.build\/yaml/g' -e 's/.markdown$$$$/.yaml/g')
# TODO: fix the dependencies. Should be able to know which files it's dependent on even without initial build.
# Search pages and transform to the build path, don't search build
	mkdir -p $(dir $@)
	yq read config/site-config.yaml > $@
	sed '/\.\.\./q' $< | yq read - | yq merge --inplace --overwrite $@ -
	yq new 'content' "`pandoc --wrap=none --lua-filter config/filters.lua $<`" | yq merge --inplace --overwrite $@ -
	yq new 'permalink' "`yq read $@ 'baseurl'``echo '$<' | sed -e 's/^pages\///g' -e 's/_index.markdown$$//g' -e 's/.markdown$$/\//g'`" | yq merge --inplace --overwrite $@ -
	yq read $@ --tojson | jq '. + {pages:[]}' | sponge $@
	$(foreach page,$(filter-out $< $(word 2, $^) $(word 3, $^),$^),jq --argjson input "`yq read --tojson $(page)`" '.pages += [$$input]' $@ | sponge $@;)
	yq read --prettyPrint $@ | sponge $@

# After the yaml files are generated we build the html using the relevant template specific in the page front matter.
$(max_html): .build/html/%.html: .build/yaml/%.yaml
# TODO: not picking up list_yaml pages
	mkdir -p $(dir $@)
	gomplate --context .=$< --template partials/ --file templates/"`yq read $< 'template'`" > $@

# Finally we minify the resulting html files and place them in the _public folder.
$(html): _public/%.html: .build/html/%.html
	mkdir -p $(dir $@)
	minify -o $@ $<


# ---------- STATIC ---------------------------------------
# Static files are first optimized and then copied into the _public/ directory.
# Otherwise they are just copied directly.

# $(sassable): _public/%.css: static/%.scss

$(minifyable): _public/%: static/%
	mkdir -p $(dir $@)
	minify -o $@ $<

$(optimizable): _public/%: static/%
	mkdir -p $(dir $@)
	cp $< $@
	image_optim --allow-lossy --no-progress $@

$(the_rest): _public/%: static/%
	mkdir -p $(dir $@)
	cp $< $@


# ---------- RSS/ATOM/Sitemap -----------------------------
# TODO: ? Just go the hugo approach and generate for each list page. Also makes it easy to just add that to the above build.
# TODO: custom generate full listing of pages for sitemap
# https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/sitemap.xml
# http://www.intertwingly.net/wiki/pie/Rss20AndAtom10Compared

# .build/feed/feed.yaml: $(yaml)
# generate yaml with standard header info and relevant pages

# _public/rss.xml: .build/feed/feed.yaml
	# gomplate
# https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/rss.xml

# _public/atom.xml: .build/feed/feed.yaml
	# gomplate
# https://gist.github.com/lpar/7ded35d8f52fef7490a5be92e6cd6937
