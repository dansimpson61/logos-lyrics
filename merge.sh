#!/bin/bash
set -e

# Fetch all branches from the origin remote
git fetch origin

# Switch to the main branch
git checkout main

# Pull the latest changes from the remote main branch
git pull origin main

# Merge the remote feature branch into main
git merge origin/feature/songlyrics-adapter

# Push the changes to the remote main branch
git push origin main