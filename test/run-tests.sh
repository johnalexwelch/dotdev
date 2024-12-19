#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🏗️  Building test container..."
if docker build -t dotfiles-test -f test/Dockerfile .; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "\n🚀 Running tests..."
docker run --rm -it dotfiles-test

# Cleanup
echo -e "\n🧹 Cleaning up..."
docker rmi dotfiles-test 2>/dev/null 