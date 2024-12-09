#!/bin/zsh

# First, clean the docs directory to ensure fresh generation
rm -rf ./docs/*

swift package \
    --allow-writing-to-directory ./docs \
    generate-documentation \
    --target Forked --target ForkedMerge --target ForkedModel --target ForkedCloudKit \
    --output-path ./docs \
    --emit-digest \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path Forked \
    --enable-inherited-docs

# Create .nojekyll file to prevent GitHub Pages from ignoring files that begin with an underscore
touch ./docs/.nojekyll

# Verify the output structure
ls -la ./docs
