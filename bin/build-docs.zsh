#!/bin/zsh

swift package --allow-writing-to-directory ./docs \
generate-documentation \
    --target Forked --target ForkedMerge --target ForkedModel --target ForkedCloudKit \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path Forked \
    --output-path ./docs \
