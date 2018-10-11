#! /bin/bash
pwd
cd /usr/panfeng/blog
unset GIT_DIR
git reset --hard
jekyll build
