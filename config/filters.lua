
function Header(el)
	el.content = {pandoc.Link(el.content, "#" .. el.identifier)}

	return el
end

-- https://pandoc.org/lua-filters.html

