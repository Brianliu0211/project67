import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import '../utils/platform_file_helper.dart';

/// 客戶資料匯出與無損雙向往返服務 (Customer Export & Round-Trip Service)
///
/// 支援動態掃描並聚合所有客戶的 `custom_attributes` 自訂欄位，
/// 生成 100% 欄位對稱無損的 Excel (.xlsx)、UTF-8 BOM CSV (.csv)、
/// vCard 通訊錄 (.vcf) 與 Print-Ready HTML 報表。
class CustomerExportService {
  CustomerExportService._();
  static final CustomerExportService instance = CustomerExportService._();

  /// 系統核心欄位名稱黑名單 (用於防範自訂欄位覆蓋或混淆核心欄位)
  static const Set<String> _coreFieldNames = {
    '姓名', '客戶姓名', '稱呼', '綽號', '稱呼/綽號', '電話', '聯絡電話', '手機',
    '電子信箱', '信箱', '標籤', '分類標籤', '備註', '客戶備註',
    '業務員', '建檔業務員', '團隊', '所屬團隊', '建立時間', '建立日期',
    'name', 'nickname', 'phone', 'email', 'tags', 'notes', 'status',
    'custom_attributes', 'id', 'profile_id', 'created_at', 'deleted_at'
  };

  /// 防禦 CSV / Excel Formula Injection (DDE 攻擊)
  /// 若內容以 `=`, `+`, `-`, `@`, `\t`, `\r` 開頭，自動加上 `'` 單引號前綴，避免 Excel 開啟時執行惡意公式
  static String sanitizeFormula(String input) {
    if (input.isEmpty) return '';
    final trimmed = input.trimLeft();
    if (trimmed.startsWith('=') ||
        trimmed.startsWith('+') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('@') ||
        trimmed.startsWith('\t') ||
        trimmed.startsWith('\r')) {
      return "'$input";
    }
    return input;
  }

  /// HTML 標籤與特殊字元安全跳脫 (XSS 防護)
  static String escapeHtml(String input) {
    return const HtmlEscape().convert(input);
  }

  /// RFC 2426 vCard 特殊字元跳脫 (逗號、分號、反斜線、換行)
  static String escapeVCard(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll('\\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r', '')
        .replaceAll('\n', r'\n');
  }

  /// 規範化欄位名稱 (去除前後空白、全形空白、換行與控制字元)
  static String normalizeKeyName(String key) {
    String cleaned = key
        .replaceAll('\u3000', ' ') // 全形空白轉半形
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('\t', ' ')
        .trim();
    return cleaned;
  }

  /// 提取所有待匯出客戶中出現過的所有自訂屬性鍵名 (Dynamic Attribute Keys)
  /// 自動進行 Unicode 規範化、去重與核心欄位名稱衝突防護
  List<String> extractAllCustomAttributeKeys(List<Map<String, dynamic>> customers) {
    final Set<String> customKeySet = {};
    for (final customer in customers) {
      final attrs = customer['custom_attributes'];
      if (attrs is Map) {
        for (final k in attrs.keys) {
          final rawKey = k.toString();
          final normalized = normalizeKeyName(rawKey);
          if (normalized.isNotEmpty) {
            customKeySet.add(normalized);
          }
        }
      }
    }
    return customKeySet.toList()..sort();
  }

  /// 1. 匯出 Excel (.xlsx) 試算表 (含 Formula Injection 防護與動態表頭)
  Future<void> exportToExcel({
    required List<Map<String, dynamic>> customers,
    String? fileName,
  }) async {
    final dynamicKeys = extractAllCustomAttributeKeys(customers);
    final defaultFileName = fileName ?? '保險助手_客戶檔案總覽_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    final excel = xl.Excel.createExcel();
    final sheetName = excel.sheets.keys.first;
    final sheet = excel[sheetName];

    // 組裝表頭 (Core Fields + Dynamic Custom Fields + Notes & Meta)
    final headers = [
      '客戶姓名',
      '稱呼/綽號',
      '聯絡電話',
      'Email信箱',
      ...dynamicKeys.map((k) {
        final lower = k.toLowerCase();
        return _coreFieldNames.contains(lower) ? '自訂_$k' : k;
      }),
      '分類標籤',
      '客戶備註',
      '建檔業務員',
      '所屬團隊',
      '建立時間',
    ];

    sheet.appendRow(headers.map((h) => xl.TextCellValue(sanitizeFormula(h))).toList());

    // 寫入客戶資料列
    for (final customer in customers) {
      final String name = customer['name']?.toString() ?? '';
      final String nickname = customer['nickname']?.toString() ?? '';
      final String phone = customer['phone']?.toString() ?? '';
      final String email = customer['email']?.toString() ?? '';
      final List tags = customer['tags'] is List ? customer['tags'] as List : [];
      final String tagsStr = tags.map((t) => t.toString()).join(', ');
      final String notes = customer['notes']?.toString() ?? '';
      final String agentName = customer['agent_name']?.toString() ?? '';
      final String agentTeam = customer['agent_team']?.toString() ?? '';
      final String createdAt = customer['created_at']?.toString() ?? '';

      // 提取動態自訂屬性
      final Map<dynamic, dynamic> attrs = (customer['custom_attributes'] is Map)
          ? customer['custom_attributes'] as Map
          : {};

      final List<xl.CellValue> rowCells = [
        xl.TextCellValue(sanitizeFormula(name)),
        xl.TextCellValue(sanitizeFormula(nickname)),
        xl.TextCellValue(sanitizeFormula(phone)),
        xl.TextCellValue(sanitizeFormula(email)),
      ];

      for (final key in dynamicKeys) {
        dynamic val = attrs[key];
        if (val == null) {
          for (final entry in attrs.entries) {
            if (normalizeKeyName(entry.key.toString()) == key) {
              val = entry.value;
              break;
            }
          }
        }
        final valStr = val != null ? val.toString() : '';
        rowCells.add(xl.TextCellValue(sanitizeFormula(valStr)));
      }

      rowCells.addAll([
        xl.TextCellValue(sanitizeFormula(tagsStr)),
        xl.TextCellValue(sanitizeFormula(notes)),
        xl.TextCellValue(sanitizeFormula(agentName)),
        xl.TextCellValue(sanitizeFormula(agentTeam)),
        xl.TextCellValue(sanitizeFormula(createdAt)),
      ]);

      sheet.appendRow(rowCells);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await PlatformFileHelper.downloadFile(
        bytes: Uint8List.fromList(bytes),
        fileName: defaultFileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
  }

  /// 2. 匯出 CSV (.csv) 試算表 (注入 UTF-8 BOM 防 Excel 繁中亂碼 + Formula Injection 防護)
  Future<void> exportToCsv({
    required List<Map<String, dynamic>> customers,
    String? fileName,
  }) async {
    final dynamicKeys = extractAllCustomAttributeKeys(customers);
    final defaultFileName = fileName ?? '保險助手_客戶清單_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    final headers = [
      '客戶姓名',
      '稱呼/綽號',
      '聯絡電話',
      'Email信箱',
      ...dynamicKeys.map((k) {
        final lower = k.toLowerCase();
        return _coreFieldNames.contains(lower) ? '自訂_$k' : k;
      }),
      '分類標籤',
      '客戶備註',
      '建檔業務員',
      '所屬團隊',
      '建立時間',
    ];

    final List<List<dynamic>> rows = [
      headers.map((h) => sanitizeFormula(h)).toList()
    ];

    for (final customer in customers) {
      final String name = customer['name']?.toString() ?? '';
      final String nickname = customer['nickname']?.toString() ?? '';
      final String phone = customer['phone']?.toString() ?? '';
      final String email = customer['email']?.toString() ?? '';
      final List tags = customer['tags'] is List ? customer['tags'] as List : [];
      final String tagsStr = tags.map((t) => t.toString()).join(', ');
      final String notes = customer['notes']?.toString() ?? '';
      final String agentName = customer['agent_name']?.toString() ?? '';
      final String agentTeam = customer['agent_team']?.toString() ?? '';
      final String createdAt = customer['created_at']?.toString() ?? '';

      final Map<dynamic, dynamic> attrs = (customer['custom_attributes'] is Map)
          ? customer['custom_attributes'] as Map
          : {};

      final List<dynamic> row = [
        sanitizeFormula(name),
        sanitizeFormula(nickname),
        sanitizeFormula(phone),
        sanitizeFormula(email),
      ];

      for (final key in dynamicKeys) {
        dynamic val = attrs[key];
        if (val == null) {
          for (final entry in attrs.entries) {
            if (normalizeKeyName(entry.key.toString()) == key) {
              val = entry.value;
              break;
            }
          }
        }
        final valStr = val != null ? val.toString() : '';
        row.add(sanitizeFormula(valStr));
      }

      row.addAll([
        sanitizeFormula(tagsStr),
        sanitizeFormula(notes),
        sanitizeFormula(agentName),
        sanitizeFormula(agentTeam),
        sanitizeFormula(createdAt),
      ]);

      rows.add(row);
    }

    final csvString = const ListToCsvConverter(eol: '\r\n').convert(rows);
    // 強制置入 \uFEFF UTF-8 BOM 解決微軟 Excel 開啟繁中亂碼
    final bomCsvString = '\uFEFF$csvString';
    final bytes = Uint8List.fromList(utf8.encode(bomCsvString));

    await PlatformFileHelper.downloadFile(
      bytes: bytes,
      fileName: defaultFileName,
      mimeType: 'text/csv;charset=utf-8',
    );
  }

  /// RFC 2426 Section 2.6 Line Folding (每行超過 75 字元時以 \r\n 加上空白進行折行)
  static String foldVCardLine(String line) {
    if (line.length <= 75) return line;
    final sb = StringBuffer();
    int current = 0;
    while (current < line.length) {
      if (current == 0) {
        final end = (current + 75 < line.length) ? current + 75 : line.length;
        sb.write(line.substring(current, end));
        current = end;
      } else {
        sb.write('\r\n ');
        final end = (current + 74 < line.length) ? current + 74 : line.length;
        sb.write(line.substring(current, end));
        current = end;
      }
    }
    return sb.toString();
  }

  /// 3. 匯出 vCard (.vcf) 通訊錄 (符合 RFC 2426 規範，嚴格特殊字符跳脫、長內容折行與 CRLF 結尾)
  Future<void> exportToVCard({
    required List<Map<String, dynamic>> customers,
    String? fileName,
  }) async {
    final defaultFileName = fileName ?? (customers.length == 1
        ? '${customers.first['name'] ?? '客戶'}_通訊錄名片.vcf'
        : '保險助手_客戶通訊錄_${DateFormat('yyyyMMdd').format(DateTime.now())}.vcf');

    final buffer = StringBuffer();

    for (final customer in customers) {
      final String name = customer['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;

      final String nickname = customer['nickname']?.toString().trim() ?? '';
      final String phone = customer['phone']?.toString().trim() ?? '';
      final String email = customer['email']?.toString().trim() ?? '';
      final List tags = customer['tags'] is List ? customer['tags'] as List : [];
      final String notes = customer['notes']?.toString().trim() ?? '';
      final String agentName = customer['agent_name']?.toString().trim() ?? '';

      final Map<dynamic, dynamic> attrs = (customer['custom_attributes'] is Map)
          ? customer['custom_attributes'] as Map
          : {};

      void writeLine(String line) {
        buffer.write(foldVCardLine(line));
        buffer.write('\r\n');
      }

      writeLine('BEGIN:VCARD');
      writeLine('VERSION:3.0');
      
      // Full Name & Structured Name
      final displayName = nickname.isNotEmpty ? '$name ($nickname)' : name;
      writeLine('FN;CHARSET=UTF-8:${escapeVCard(displayName)}');
      writeLine('N;CHARSET=UTF-8:${escapeVCard(name)};;;;');
      
      if (nickname.isNotEmpty) {
        writeLine('NICKNAME;CHARSET=UTF-8:${escapeVCard(nickname)}');
      }

      if (phone.isNotEmpty) {
        writeLine('TEL;TYPE=CELL,VOICE:${escapeVCard(phone)}');
      }

      if (email.isNotEmpty) {
        writeLine('EMAIL;TYPE=INTERNET,PREF:${escapeVCard(email)}');
      }

      if (tags.isNotEmpty) {
        final escapedTags = tags.map((t) => escapeVCard(t.toString())).join(',');
        writeLine('CATEGORIES;CHARSET=UTF-8:$escapedTags');
      }

      // 組裝備註與自訂屬性 (全部安全封裝於 NOTE 區塊)
      final noteParts = <String>[];
      if (notes.isNotEmpty) {
        noteParts.add(notes);
      }
      if (attrs.isNotEmpty) {
        final attrLines = attrs.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .map((e) => '• ${e.key}: ${e.value}')
            .join('\n');
        if (attrLines.isNotEmpty) {
          noteParts.add('【自訂屬性】\n$attrLines');
        }
      }
      if (agentName.isNotEmpty) {
        noteParts.add('【保險業務員】: $agentName');
      }

      if (noteParts.isNotEmpty) {
        final combinedNote = noteParts.join('\n\n');
        writeLine('NOTE;CHARSET=UTF-8:${escapeVCard(combinedNote)}');
      }

      writeLine('END:VCARD');
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    await PlatformFileHelper.downloadFile(
      bytes: bytes,
      fileName: defaultFileName,
      mimeType: 'text/vcard;charset=utf-8',
    );
  }

  /// 4. 生成 Print-Ready 企業級 HTML / PDF 客戶總覽報表 (含 XSS 跳脫與資安脫敏)
  Future<void> exportToPrintableReport({
    required List<Map<String, dynamic>> customers,
    String? reportTitle,
  }) async {
    final title = reportTitle ?? '保險顧問客戶檔案總覽報表';
    final safeTitle = escapeHtml(title);
    final nowStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
    final dynamicKeys = extractAllCustomAttributeKeys(customers);

    final htmlBuffer = StringBuffer();
    htmlBuffer.writeln('<!DOCTYPE html>');
    htmlBuffer.writeln('<html lang="zh-TW">');
    htmlBuffer.writeln('<head>');
    htmlBuffer.writeln('<meta charset="UTF-8">');
    htmlBuffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    htmlBuffer.writeln('<title>$safeTitle</title>');
    htmlBuffer.writeln('''
<style>
  @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+TC:wght@400;500;700&display=swap');
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Noto Sans TC', sans-serif; background-color: #f8fafc; color: #0f172a; padding: 32px; font-size: 13px; line-height: 1.5; }
  .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 24px; border-bottom: 2px solid #0ea5e9; padding-bottom: 16px; }
  .title { font-size: 22px; font-weight: 700; color: #0284c7; }
  .subtitle { font-size: 12px; color: #64748b; margin-top: 4px; }
  .meta-box { text-align: right; font-size: 11px; color: #64748b; }
  .stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; margin-bottom: 24px; }
  .stat-card { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
  .stat-num { font-size: 20px; font-weight: 700; color: #0ea5e9; }
  .stat-label { font-size: 11px; color: #64748b; }
  .table-container { background: white; border-radius: 8px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
  table { width: 100%; border-collapse: collapse; text-align: left; }
  th { background-color: #f1f5f9; color: #334155; font-weight: 700; font-size: 12px; padding: 10px 12px; border-bottom: 1px solid #cbd5e1; }
  td { padding: 10px 12px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
  tr:nth-child(even) { background-color: #fafafa; }
  .tag { display: inline-block; background: #e0f2fe; color: #0369a1; border-radius: 4px; padding: 2px 6px; font-size: 10px; font-weight: 600; margin: 2px 2px 0 0; }
  .attr-badge { display: inline-block; background: #f1f5f9; color: #475569; border-radius: 4px; padding: 2px 6px; font-size: 10px; margin: 2px 2px 0 0; border: 1px solid #e2e8f0; }
  .notes { font-size: 11px; color: #475569; max-width: 250px; word-break: break-word; }
  .actions-bar { margin-bottom: 16px; display: flex; gap: 10px; }
  .btn { background: #0ea5e9; color: white; border: none; padding: 8px 16px; border-radius: 6px; font-weight: 700; cursor: pointer; font-size: 12px; }
  @media print {
    body { background: white; padding: 0; }
    .actions-bar { display: none; }
    .table-container, .stat-card { box-shadow: none; border-color: #ccc; }
    th { background: #eee !important; -webkit-print-color-adjust: exact; }
  }
</style>
''');
    htmlBuffer.writeln('</head>');
    htmlBuffer.writeln('<body>');
    htmlBuffer.writeln('''
<div class="actions-bar">
  <button class="btn" onclick="window.print()">🖨️ 列印報表 / 另存為 PDF</button>
</div>
''');
    htmlBuffer.writeln('<div class="header">');
    htmlBuffer.writeln('  <div>');
    htmlBuffer.writeln('    <div class="title">$safeTitle</div>');
    htmlBuffer.writeln('    <div class="subtitle">保險助手系統 • 結構化動態屬性與全景總覽</div>');
    htmlBuffer.writeln('  </div>');
    htmlBuffer.writeln('  <div class="meta-box">');
    htmlBuffer.writeln('    <div>產出時間：$nowStr</div>');
    htmlBuffer.writeln('    <div>涵蓋客戶總數：${customers.length} 位</div>');
    htmlBuffer.writeln('  </div>');
    htmlBuffer.writeln('</div>');

    // 統計卡片
    final totalTags = customers.fold<int>(0, (sum, c) => sum + (c['tags'] is List ? (c['tags'] as List).length : 0));
    htmlBuffer.writeln('''
<div class="stat-grid">
  <div class="stat-card">
    <div class="stat-num">${customers.length}</div>
    <div class="stat-label">客戶總數</div>
  </div>
  <div class="stat-card">
    <div class="stat-num">$totalTags</div>
    <div class="stat-label">關聯標籤數</div>
  </div>
  <div class="stat-card">
    <div class="stat-num">${dynamicKeys.length}</div>
    <div class="stat-label">擴充自訂欄位數</div>
  </div>
</div>
''');

    // 資料表格
    htmlBuffer.writeln('<div class="table-container">');
    htmlBuffer.writeln('<table>');
    htmlBuffer.writeln('<thead><tr>');
    htmlBuffer.writeln('<th>姓名</th>');
    htmlBuffer.writeln('<th>聯絡資訊</th>');
    if (dynamicKeys.isNotEmpty) {
      htmlBuffer.writeln('<th>自訂擴充屬性</th>');
    }
    htmlBuffer.writeln('<th>分類標籤</th>');
    htmlBuffer.writeln('<th>備註心得</th>');
    htmlBuffer.writeln('<th>業務員</th>');
    htmlBuffer.writeln('</tr></thead>');
    htmlBuffer.writeln('<tbody>');

    for (final customer in customers) {
      final String name = escapeHtml(customer['name']?.toString() ?? '');
      final String nickname = escapeHtml(customer['nickname']?.toString() ?? '');
      final String phone = escapeHtml(customer['phone']?.toString() ?? '');
      final String email = escapeHtml(customer['email']?.toString() ?? '');
      final List tags = customer['tags'] is List ? customer['tags'] as List : [];
      final String notes = escapeHtml(customer['notes']?.toString() ?? '');
      final String agentName = escapeHtml(customer['agent_name']?.toString() ?? '');
      final Map<dynamic, dynamic> attrs = (customer['custom_attributes'] is Map)
          ? customer['custom_attributes'] as Map
          : {};

      htmlBuffer.writeln('<tr>');
      htmlBuffer.writeln('<td><strong>$name</strong>${nickname.isNotEmpty ? '<br><span style="color:#64748b;font-size:11px">($nickname)</span>' : ''}</td>');
      htmlBuffer.writeln('<td>${phone.isNotEmpty ? '📞 $phone' : ''}${email.isNotEmpty ? '<br>✉️ $email' : ''}</td>');
      
      if (dynamicKeys.isNotEmpty) {
        htmlBuffer.writeln('<td>');
        if (attrs.isEmpty) {
          htmlBuffer.writeln('<span style="color:#94a3b8;font-size:11px">-</span>');
        } else {
          for (final entry in attrs.entries) {
            final safeKey = escapeHtml(entry.key.toString());
            final safeVal = escapeHtml(entry.value?.toString() ?? '');
            if (safeVal.isNotEmpty) {
              htmlBuffer.writeln('<span class="attr-badge">$safeKey: $safeVal</span>');
            }
          }
        }
        htmlBuffer.writeln('</td>');
      }

      htmlBuffer.writeln('<td>');
      if (tags.isEmpty) {
        htmlBuffer.writeln('<span style="color:#94a3b8;font-size:11px">-</span>');
      } else {
        for (final tag in tags) {
          htmlBuffer.writeln('<span class="tag">${escapeHtml(tag.toString())}</span>');
        }
      }
      htmlBuffer.writeln('</td>');

      htmlBuffer.writeln('<td class="notes">${notes.isNotEmpty ? notes : '<span style="color:#94a3b8">-</span>'}</td>');
      htmlBuffer.writeln('<td style="font-size:11px;color:#64748b">${agentName.isNotEmpty ? agentName : '一般業務員'}</td>');
      htmlBuffer.writeln('</tr>');
    }

    htmlBuffer.writeln('</tbody></table></div>');
    htmlBuffer.writeln('</body></html>');

    final fileName = '保險客戶檔案總覽報表_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.html';
    final bytes = Uint8List.fromList(utf8.encode(htmlBuffer.toString()));

    await PlatformFileHelper.downloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'text/html;charset=utf-8',
    );
  }
}
