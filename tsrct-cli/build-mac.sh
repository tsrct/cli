
mkdir -p out
dart compile exe --output out/tsrct --target-os macos bin/tsrct.dart

cp out/tsrct ~/tools/tsrct/