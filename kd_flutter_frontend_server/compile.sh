#!/usr/bin/env bash

# compile flutter_frontend_server.dart.snapshot
# 修改FLUTTER_HOME为对应的flutter sdk目录
FLUTTER_HOME="/Users/pengzimao/Documents/leo_project/flutter2"
$FLUTTER_HOME/bin/dart --snapshot-kind=kernel --snapshot=frontend_server.dart.snapshot --packages=.dart_tool/package_config.json  bin/starter.dart