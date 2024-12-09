#!/bin/zsh

# First, clean the docs directory to ensure fresh generation
rm -rf ./docs/*

# Array of targets
targets=("Forked" "ForkedMerge" "ForkedModel" "ForkedCloudKit")

# Generate documentation for each target separately
for target in $targets; do
    swift package \
        --allow-writing-to-directory ./docs \
        generate-documentation \
        --target $target \
        --output-path "./docs/$target" \
        --emit-digest \
        --disable-indexing \
        --transform-for-static-hosting \
        --hosting-base-path "Forked/$target" \
        --enable-inherited-docs
done

# Create .nojekyll file to prevent GitHub Pages from ignoring files that begin with an underscore
touch ./docs/.nojekyll

# Create a simple index.html that links to each package's documentation
cat > ./docs/index.html << EOL
<!DOCTYPE html>
<html>
<head>
    <title>Documentation</title>
</head>
<body>
    <h1>Available Documentation</h1>
    <ul>
EOL

for target in $targets; do
    echo "        <li><a href='./$target/documentation/$target/'>${target}</a></li>" >> ./docs/index.html
done

cat >> ./docs/index.html << EOL
    </ul>
</body>
</html>
EOL

# Verify the output structure
ls -la ./docs
