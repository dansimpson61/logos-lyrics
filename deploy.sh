#!/bin/bash
set -ex

echo "Pulling latest changes..."
git pull

echo "Installing dependencies..."
bundle install --verbose > bundle.log 2>&1

echo "Starting application..."
bundle exec rackup > rackup.log 2>&1
