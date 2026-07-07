#!/usr/bin/env bash

if [ $(playerctl status) = "Playing" ]; then
  exit 0
else
  exit 1
fi
