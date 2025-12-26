#!/bin/bash
cd /home/engine/project
git add -A
git status
git diff --cached --stat
