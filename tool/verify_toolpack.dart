import 'dart:io';

void main() {
  print('==============================================');
  print('   開始執行工具包版本與專案配置校對 (Verification)');
  print('==============================================');
  
  var hasError = false;

  // 1. 讀取 docs/工具包.md
  final toolpackFile = File('docs/工具包.md');
  if (!toolpackFile.existsSync()) {
    print('❌ 錯誤：找不到 docs/工具包.md 文件！');
    exit(1);
  }
  final toolpackContent = toolpackFile.readAsStringSync();

  // 2. 讀取 pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ 錯誤：找不到 pubspec.yaml 專案設定檔！');
    exit(1);
  }
  final pubspecContent = pubspecFile.readAsStringSync();

  // 3. 比對套件版本
  final packagesToCheck = ['supabase_flutter', 'flutter_dotenv', 'cupertino_icons'];
  print('\n[1/3] 正在比對 pubspec.yaml 與 docs/工具包.md 中的依賴套件版本...');
  
  for (final pkg in packagesToCheck) {
    // 從 pubspec.yaml 找版本，例如 supabase_flutter: ^2.15.4
    final pubspecRegExp = RegExp('$pkg:\\s*(\\S+)');
    final pubspecMatch = pubspecRegExp.firstMatch(pubspecContent);
    if (pubspecMatch == null) {
      print('⚠️ 警告：pubspec.yaml 中找不到套件: $pkg');
      continue;
    }
    final pubspecVersion = pubspecMatch.group(1)!.replaceAll("'", "").replaceAll('"', '');

    // 從 docs/工具包.md 找版本，支援 **`supabase_flutter`** (`^2.15.4`) 或類似格式
    final toolpackRegExp = RegExp('\\*\\*`$pkg`\\*\\*.*?\\(([^)]+)\\)');
    final toolpackMatch = toolpackRegExp.firstMatch(toolpackContent);
    if (toolpackMatch == null) {
      print('❌ 錯誤：docs/工具包.md 中找不到套件 [$pkg] 的版本格式，請確認是否符合規範：**`$pkg`** (`版本號`)');
      hasError = true;
      continue;
    }
    final toolpackVersion = toolpackMatch.group(1)!.replaceAll('`', '').trim();

    if (pubspecVersion != toolpackVersion) {
      print('❌ 版本不對齊：套件 [$pkg]');
      print('   - 專案實際設定 (pubspec.yaml): $pubspecVersion');
      print('   - 工具包文件 (docs/工具包.md): $toolpackVersion');
      hasError = true;
    } else {
      print('✅ 套件 [$pkg] 已對齊一致 ($pubspecVersion)');
    }
  }

  // 4. 比對 Flutter SDK 與 Dart SDK 版本 (與本機環境比對)
  print('\n[2/3] 正在比對本機環境 SDK 版本與 docs/工具包.md 建議版本...');
  
  final docFlutterReg = RegExp(r'Flutter SDK\s*\(建議版本\s*v?([\d\.]+)\)');
  final docFlutterMatch = docFlutterReg.firstMatch(toolpackContent);
  
  final docDartReg = RegExp(r'Dart SDK\s*`?([\d\.]+)`?');
  final docDartMatch = docDartReg.firstMatch(toolpackContent);

  if (docFlutterMatch != null) {
    final docFlutterVer = docFlutterMatch.group(1);
    print('📌 工具包建議 Flutter SDK 版本: v$docFlutterVer');
    
    try {
      final result = Process.runSync('puro', ['flutter', '--version']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final localFlutterReg = RegExp(r'Flutter ([\d\.]+)');
        final localFlutterMatch = localFlutterReg.firstMatch(output);
        if (localFlutterMatch != null) {
          final localFlutterVer = localFlutterMatch.group(1);
          if (localFlutterVer != docFlutterVer) {
            print('⚠️ 警告：Flutter SDK 版本與建議不符！');
            print('   - 本機目前版本: v$localFlutterVer');
            print('   - 工具包建議版: v$docFlutterVer');
            print('   (若此為開發環境刻意調整，請確保已與團隊對齊並更新工具包文件)');
          } else {
            print('✅ 本機 Flutter SDK 版本與工具包一致 (v$docFlutterVer)');
          }
        } else {
          print('⚠️ 無法解析本機 Flutter 版本輸出內容。');
        }
      } else {
        print('⚠️ 執行 puro flutter --version 失敗，代碼: ${result.exitCode}');
      }
    } catch (e) {
      print('⚠️ 無法自動執行 puro flutter --version，略過本機比對。($e)');
    }
  } else {
    print('⚠️ 警告：docs/工具包.md 中找不到 Flutter SDK 建議版本的標記格式。');
  }

  if (docDartMatch != null) {
    final docDartVer = docDartMatch.group(1);
    print('📌 工具包建議 Dart SDK 版本: $docDartVer');
  }

  // 5. 輸出校對結果
  print('\n[3/3] 校對總結:');
  if (hasError) {
    print('❌ 校對失敗：工具包文件與專案實際設定不符，請修正文件或套件設定！');
    exit(1);
  } else {
    print('🎉 校對成功！工具包與專案設定完全一致。');
    exit(0);
  }
}
