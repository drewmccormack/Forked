#!/bin/zsh
# Will generate docs for GitHub Pages at URLs like
# https://drewmccormack.github.io/Forked/ForkedMerge/documentation/forkedmerge/

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
