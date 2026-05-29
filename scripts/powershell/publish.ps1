#!/usr/bin/env pwsh
flutter build apk --release `
  --dart-define=AUTHSERVER=$args[0] `
  --dart-define=API_URI=$args[1]
