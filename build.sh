#!/bin/bash

mkdir docs
rsync static/* docs/static/
pandoc -i index.md -o docs/index.html --css static/main.css --standalone
