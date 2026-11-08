#!/usr/bin/env bash
cd "$(dirname "$0")"
exec ./runtime/bin/java -Xms512M -Xmx1500M -jar paper.jar --nogui
