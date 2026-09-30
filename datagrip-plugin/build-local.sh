#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATAGRIP_APP="${DATAGRIP_APP:-/Applications/DataGrip.app}"
IDE_CONTENTS="$DATAGRIP_APP/Contents"
OUT_DIR="$ROOT_DIR/build"
CLASSES_DIR="$OUT_DIR/classes"
PLUGIN_DIR="$OUT_DIR/plugin/WorkPetDataGripNotifier"
ZIP_PATH="$OUT_DIR/WorkPetDataGripNotifier.zip"

if [[ ! -d "$IDE_CONTENTS" ]]; then
  echo "DataGrip.app not found: $DATAGRIP_APP" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$CLASSES_DIR" "$PLUGIN_DIR/lib" "$PLUGIN_DIR/META-INF"

CLASSPATH="$IDE_CONTENTS/lib/app.jar"
CLASSPATH="$CLASSPATH:$IDE_CONTENTS/lib/util-8.jar"
CLASSPATH="$CLASSPATH:$IDE_CONTENTS/lib/util_rt.jar"
CLASSPATH="$CLASSPATH:$IDE_CONTENTS/lib/annotations.jar"
CLASSPATH="$CLASSPATH:$IDE_CONTENTS/plugins/DatabaseTools/lib/database-plugin.jar"
CLASSPATH="$CLASSPATH:$IDE_CONTENTS/plugins/DatabaseTools/lib/jdbc-console.jar"
CLASSPATH="$CLASSPATH:$IDE_CONTENTS/lib/modules/intellij.grid.core.impl.jar"

find "$ROOT_DIR/src/main/java" -name '*.java' > "$OUT_DIR/sources.txt"

javac --release 17 -cp "$CLASSPATH" -d "$CLASSES_DIR" @"$OUT_DIR/sources.txt"

jar cf "$PLUGIN_DIR/lib/workpet-datagrip-notifier.jar" -C "$CLASSES_DIR" .
cp "$ROOT_DIR/src/main/resources/META-INF/plugin.xml" "$PLUGIN_DIR/META-INF/plugin.xml"

cd "$OUT_DIR/plugin"
zip -qr "$ZIP_PATH" WorkPetDataGripNotifier

echo "Built plugin: $ZIP_PATH"
echo "Install in DataGrip: Settings > Plugins > gear icon > Install Plugin from Disk..."
