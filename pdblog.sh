#! /usr/bin/env sh

# === begin config ===

SITE_URL="https://gord.io"
SITE_AUTHOR="Gord Stephen"
SITE_TITLE="Gord Stephen"
SITE_SUBTITLE="Bits and things"
SITE_DESCRIPTION="Gord Stephen's software musings"
SITE_FOOTER='Site contents licensed <a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a>'

POSTS_DIR="posts"
ASSETS_DIR="assets"
THEME_DIR="theme"
OUT_DIR="out"

# === end config ===

header="$THEME_DIR"/header.html
post_template="$THEME_DIR"/post.html
error_template="$THEME_DIR"/404.html
footer="$THEME_DIR"/footer.html
highlight_file="$THEME_DIR"/highlighting.theme

if [ -d "$OUT_DIR" ]; then
    echo "Destination directory $OUT_DIR already exists, removing..."
    rm -r "$OUT_DIR"
fi

# Process files to HTML

mkdir -p "$OUT_DIR"
homepage="$OUT_DIR"/index.html
errorpage="$OUT_DIR"/404.html

echo "Generating $homepage..."
echo "" | pandoc --template="$header" \
                 --metadata title="$SITE_DESCRIPTION" \
                 --metadata author="$SITE_AUTHOR" \
                 --variable sitetitle="$SITE_TITLE" \
                 --variable sitesubtitle="$SITE_SUBTITLE" \
                 -t html  > "$homepage"
printf '\n<main>\n  <ol class="posts">\n' >> "$homepage"

ls $POSTS_DIR/*.md | sort -r | while read file; do

    [ -f "$file" ] || continue

    # Extract date and title text
    filename=$(basename "$file" ".md")
    title=$(echo "$filename" | sed -E 's/^[0-9]{8}-(.*)$/\1/')
    timestamp=$(echo "$filename" | sed -E 's/^([0-9]{8})-.*$/\1/')

    # Process title text
    slug=$(echo "$title" | tr -dc '[:alnum:][:space:]'  | tr '[:upper:]' '[:lower:]' | tr -s ' -_'  | tr ' _' '-' )
    link=/"$slug"
    url="$SITE_URL"/"$slug"
    page="$OUT_DIR"/"$slug"/index.html

    echo "Processing $file to $page"

    # Process timestamp
    machinetime=$(date -d "$timestamp" '+%Y-%m-%d')
    humantime=$(date -d "$timestamp" '+%B %-e, %Y')

    # Create HTML page
    mkdir -p $(dirname "$page")
    pandoc --template="$post_template" \
           --metadata title="$title" \
           --metadata author="$SITE_AUTHOR" \
           --variable titlesuffix="$SITE_DESCRIPTION" \
           --variable sitetitle="$SITE_TITLE" \
           --variable sitesubtitle="$SITE_SUBTITLE" \
           --variable humantime="$humantime" \
           --variable machinetime="$machinetime" \
           --variable sitefooter="$SITE_FOOTER" \
           --highlight-style "$highlight_file" \
           --shift-heading-level-by=1 \
           -f markdown -t html "$file" > "$page"

    # Update home page
    printf '    <li>\n      <time datetime="%s">%s</time>\n      <a href="%s">%s</a>\n    </li>\n' "$machinetime" "$humantime" "$link" "$title" >> "$homepage"

done

printf '  </ol>\n</main>\n\n' >> "$homepage"
echo "" | pandoc --template="$footer" \
                 --metadata title="$SITE_DESCRIPTION" \
                 --metadata author="$SITE_AUTHOR" \
                 --variable sitetitle="$SITE_TITLE" \
                 --variable sitesubtitle="$SITE_SUBTITLE" \
                 --variable sitefooter="$SITE_FOOTER" \
                 -t html >> "$homepage"

echo "Generating $errorpage..."
echo "" | pandoc --template="$error_template" \
                 --metadata title="$SITE_DESCRIPTION" \
                 --metadata author="$SITE_AUTHOR" \
                 --variable sitetitle="$SITE_TITLE" \
                 --variable sitesubtitle="$SITE_SUBTITLE" \
                 --variable sitefooter="$SITE_FOOTER" \
                 -t html  > "$errorpage"

# Copy assets and theme includes

for f in $ASSETS_DIR/*; do
    [ -f "$f" ] || [ -d "$f" ] || continue
    echo "Copying $f to $OUT_DIR/"
    cp -r $f $OUT_DIR/
done

for f in $THEME_DIR/includes/*; do
    [ -f "$f" ] || [ -d "$f" ] || continue
    echo "Copying $f to $OUT_DIR/"
    cp -r $f $OUT_DIR/
done
