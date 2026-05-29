#!/bin/bash
flutter build apk --release \
  --dart-define=AUTHSERVER=$1 \
  --dart-define=API_URI=$2
