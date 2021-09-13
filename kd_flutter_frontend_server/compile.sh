#!/usr/bin/env bash

# compile flutter_frontend_server.dart.snapshot
dart --snapshot-kind=kernel --snapshot=frontend_server.dart.snapshot --packages=.dart_tool/package_config.json   bin/starter.dart