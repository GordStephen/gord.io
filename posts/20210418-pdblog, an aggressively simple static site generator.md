_TL;DR: I made [a thing](https://pdblog.org) for blogging!_

# Self-aggrandizing history lesson

A few years ago I found myself wanting to quickly stitch a collection of
folders of Emacs Org-Mode files into a web site. I had used
[mkdocs](https://www.mkdocs.org/) for that
in the past (albeit with Markdown, not Org-Mode), which had worked reasonably
well, other than the fact that you needed to install Python and a bunch of
dependencies. I was running Arch Linux (by the way) and the supposedly
simple task of installing mkdocs started breaking things. On top of that, I
had also been using Jekyll for some other sites and so had bunch of Ruby gems
cluttering up my package manager as well.

This all seemed overly complicated. Do you really need multiple levels of
package management infrastructure and fancy languages to glue together some
text files? I already knew I wanted to use [Pandoc](https://pandoc.org/)
for converting Org-Mode to HTML, could the rest of the work not be done in a
shell script?

As it turns out, yes, it could, and [pdsite](https://pdsite.org) was born.
In retrospect, pdsite was a bit of a mess, spewing a bunch of little temporary
files across your folder structure to address the fact that shell scripts
don't really have a good way of dealing with hierarchical data structures (or
any data structures, for that matter). Much of the text
processing relied on sed and awk one-liners that were anything but readable.
There were also some GNU-isms that caused issues for POSIX compliance.

Fast-forward five years, and I found myself wanting to set up a simple blog. 
Could I use pdsite? _Sure._ Should I? _Probably not?_ I wanted something
simpler (no multi-level folder structures) but also a little different (a
chronological index on the home page). But hey, pdsite was only 200 lines of
shell, a blogging analog (_pdblog_, if you will) should be easier, right?

# pdblog: working hard at doing less

Turns out, simple blogs are simple. I give you,
[pdblog.sh](https://github.com/GordStephen/pdblog/blob/master/pdblog.sh)!
The script weighs in at
just over 100 lines, nearly half of which is setting config variables or passing
those variables into pandoc. There's really not much going on: it's
signficantly simpler and easier to understand than pdsite. Hooray!

You can read the code yourself, but the basic premise is:

 - iterate through a flat collection of text files in a specific folder: each
   file name provides the publication date (for ordering) and post title
 - convert each file to an HTML page via Pandoc
 - along the way, append HTML with the post titles and dates to the index page

Do you really need anything more in a blog? I don't - that's why I'm using it
to generate this very site. I made [another website](https://pdblog.org)
(also using pdblog, of course) which gets into
more details on usage and theming, if you're interested in trying it out
for yourself.

# Syntax highlighting

In addition to converting between pretty much every document format you can
think of _and_ providing a full document templating engine, pandoc will
highlight code syntax for you as well, using KDE's text editor
[parsing](https://docs.kde.org/trunk5/en/kate/katepart/highlight.html)
and
[coloring](https://docs.kde.org/trunk5/en/kate/katepart/color-themes.html#color-themes-json)
standards. Pandoc's default color scheme is the pygments
default, which is... not my favorite. I'm a big fan of the
[Base16](http://chriskempson.com/projects/base16/)
system, as well as its default color palette, which surprisingly didn't seem
to be available as a KDE theme. So I figured I could manually set up the
subset of a full-blown KDE color theme that pandoc uses:
 
-------------------------------------------------------------------------------
 base16 id    default color      base16 guidelines     KDE syntax elements
-----------  ----------------  ---------------------  -------------------------
 base00        light            default background      base background color

 base03        mid              comments,               `Comment`,
                                invisibles              `CommentVar`,
                                                        `Documentation`

 base05        dark             default foreground,      base text color,
                                caret,                   `Operator`,
                                delimiters,              `Other`
                                operators 

 base08        red              variables,               `Variable`
                                XML tags

 base09        orange           integers,               `Constant`,
                                boolean,                `Float`,
                                constants,              `DecVal`,
                                XML attributes          `BaseN`

 base0A        yellow           classes                 `DataType`

 base0B        green            strings,                `String`,
                                inherited class         `VerbatimString`,
                                                        `Char`

 base0C        cyan             support,                `Preprocessor`,
                                regular expressions,    `SpecialString`,
                                escape characters       `SpecialChar`,
                                                        `Annotation`,
                                                        `Extension`,
                                                        `Attribute`

 base0D        blue             functions,              `Function`
                                methods,
                                attribute IDs

 base0E        magenta          keywords,               `Keyword`,
                                storage,                `ControlFlow`,
                                selector                `Import`

 base0F        brown            deprecated

-------------------------------------------------------------------------------


The KDE elements also include `BuiltIn` (which I left unthemed),
`Error` and `Alert` (which I set to red), `Warning`, and
`Information` (which I set to yellow and cyan, respectively).

Here's the result, using some Julia code as an example:

```julia
# This is myfun written in Julia
function myfun(w::Bool, x::Int, y::Float64, z::String)
    println("Hello world!")
    println(z, "\t", 35 + 12.2, "\t", w * (x + y))
    return w ? x + y : x - y
end
```

Pretty snazzy, right? The
[theme file](https://github.com/GordStephen/pdblog/blob/master/theme/highlighting.theme)
is available as part of the pdblog default theme.

# Future work (or lack thereof)

pdblog is intentionally very simple, and I don't intend to change that by
adding too many new features. I'll probably add an RSS feed (handled in the
same way as the index page), but beyond that
I suspect most of my future enhancements will be to my
site's theme as opposed to the core pdblog script. I'm quite pleased with the
tool as-is, and hope others find it useful as well.
