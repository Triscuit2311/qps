#!/usr/bin/bash

zig build test 2>&1 | cat
