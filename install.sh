#!/bin/bash

git clone https://github.com/Ai-test001/test

apt install apache2

systemctl start apache2

rm -rf /var/www/html/*

mv test/index.html /var/www/html/
