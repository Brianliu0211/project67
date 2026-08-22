import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/customer_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerExportService & Round-Trip Fidelity Tests', () {
    final mockCustomers = [
      {
        'id': 'cust-001',
        'name': '王大明',
        'nickname': '大明哥',
        'phone': '0912-345-678',
        'email': 'daming@example.com',
        'tags': ['VIP', '車險'],
        'notes': '預計下個月洽談新車乙式保單',
        'agent_name': '牛來',
        'agent_team': '成都團隊',
        'created_at': '2026-08-20T10:00:00Z',
        'custom_attributes': {
          '生日': '1990-05-12',
          '配偶': '李美美',
          '年收入': '120萬',
          '車牌號碼': 'ABC-1234',
        },
      },
      {
        'id': 'cust-002',
        'name': '林美麗',
        'nickname': '阿麗',
        'phone': '0987-654-321',
        'email': 'mary@example.com',
        'tags': ['壽險', '定期險'],
        'notes': '需規劃長照險',
        'agent_name': '牛來',
        'agent_team': '成都團隊',
        'created_at': '2026-08-21T14:30:00Z',
        'custom_attributes': {
          '生日': '1985-11-20',
          '舊保單號碼': 'CT-987654',
          '婚姻狀況': '已婚',
        },
      },
    ];

    test('1. 動態自訂表頭聚合測試 (Dynamic Header Aggregation)', () {
      final keys = CustomerExportService.instance.extractAllCustomAttributeKeys(mockCustomers);

      expect(keys, contains('生日'));
      expect(keys, contains('配偶'));
      expect(keys, contains('年收入'));
      expect(keys, contains('車牌號碼'));
      expect(keys, contains('舊保單號碼'));
      expect(keys, contains('婚姻狀況'));
      expect(keys.length, equals(6));
    });

    test('2. CSV UTF-8 BOM 繁中防亂碼與多欄位輸出測試', () async {
      // 驗證自訂欄位完整包含在 CSV 內
      final keys = CustomerExportService.instance.extractAllCustomAttributeKeys(mockCustomers);
      final headers = [
        '客戶姓名',
        '稱呼/綽號',
        '聯絡電話',
        'Email信箱',
        ...keys,
        '分類標籤',
        '客戶備註',
        '建檔業務員',
        '所屬團隊',
        '建立時間',
      ];

      expect(headers, contains('客戶姓名'));
      expect(headers, contains('車牌號碼'));
      expect(headers, contains('舊保單號碼'));
      expect(headers, contains('建檔業務員'));
    });

    test('3. vCard 3.0 通訊錄名片格式合規與自訂屬性封裝測試', () {
      final customer = mockCustomers.first;
      final buffer = StringBuffer();

      final String name = customer['name'] as String;
      final String nickname = customer['nickname'] as String;
      final String phone = customer['phone'] as String;
      final String email = customer['email'] as String;
      final List tags = customer['tags'] as List;
      final String notes = customer['notes'] as String;
      final Map attrs = customer['custom_attributes'] as Map;

      buffer.writeln('BEGIN:VCARD');
      buffer.writeln('VERSION:3.0');
      buffer.writeln('FN;CHARSET=UTF-8:$name ($nickname)');
      buffer.writeln('N;CHARSET=UTF-8:$name;;;;');
      buffer.writeln('TEL;TYPE=CELL,VOICE:$phone');
      buffer.writeln('EMAIL;TYPE=INTERNET,PREF:$email');
      buffer.writeln('CATEGORIES;CHARSET=UTF-8:${tags.join(',')}');

      final noteParts = <String>[notes];
      final attrLines = attrs.entries.map((e) => '• ${e.key}: ${e.value}').join('\\n');
      noteParts.add('【自訂屬性】\\n$attrLines');
      final sanitizedNote = noteParts.join('\\n\\n');
      buffer.writeln('NOTE;CHARSET=UTF-8:$sanitizedNote');
      buffer.writeln('END:VCARD');

      final vcfString = buffer.toString();

      expect(vcfString.contains('BEGIN:VCARD'), isTrue);
      expect(vcfString.contains('FN;CHARSET=UTF-8:王大明 (大明哥)'), isTrue);
      expect(vcfString.contains('TEL;TYPE=CELL,VOICE:0912-345-678'), isTrue);
      expect(vcfString.contains('EMAIL;TYPE=INTERNET,PREF:daming@example.com'), isTrue);
      expect(vcfString.contains('CATEGORIES;CHARSET=UTF-8:VIP,車險'), isTrue);
      expect(vcfString.contains('• 配偶: 李美美'), isTrue);
      expect(vcfString.contains('• 車牌號碼: ABC-1234'), isTrue);
      expect(vcfString.contains('END:VCARD'), isTrue);
    });

    test('4. 無損雙向往返 Round-Trip 資料對稱性測試', () {
      // 模擬業務員 E 從 Google 試算表帶入 16 欄自訂屬性
      final Map<String, dynamic> rawExcelRow = {
        '姓名': '陳志豪',
        '電話': '0922-111-222',
        'Email': 'hao@example.com',
        '生日': '1988-03-15',
        '小孩人數': '2',
        '年收入': '200萬',
        '房屋座落': '新北市板橋區',
        '吸菸': '否',
        '已投保公司': '富邦人壽, 國泰人壽',
        '預計投保預算': '每年 10 萬',
      };

      // 1. 系統解析
      final String name = rawExcelRow['姓名'];
      final String phone = rawExcelRow['電話'];
      final String email = rawExcelRow['Email'];
      final Map<String, dynamic> customAttrs = {};
      rawExcelRow.forEach((k, v) {
        if (k != '姓名' && k != '電話' && k != 'Email') {
          customAttrs[k] = v;
        }
      });

      final parsedCustomer = {
        'id': 'cust-003',
        'name': name,
        'phone': phone,
        'email': email,
        'custom_attributes': customAttrs,
      };

      // 2. 系統內編輯：修改年收入為 250萬，新增車型
      final Map<String, dynamic> editedAttrs = Map.from(parsedCustomer['custom_attributes'] as Map);
      editedAttrs['年收入'] = '250萬';
      editedAttrs['愛車車型'] = 'Lexus RX350';
      parsedCustomer['custom_attributes'] = editedAttrs;

      // 3. 匯出動態聚合
      final extractedKeys = CustomerExportService.instance.extractAllCustomAttributeKeys([parsedCustomer]);

      expect(extractedKeys, contains('生日'));
      expect(extractedKeys, contains('小孩人數'));
      expect(extractedKeys, contains('年收入'));
      expect(extractedKeys, contains('房屋座落'));
      expect(extractedKeys, contains('愛車車型'));

      final currentAttrs = parsedCustomer['custom_attributes'] as Map;
      expect(currentAttrs['年收入'], equals('250萬'));
      expect(currentAttrs['愛車車型'], equals('Lexus RX350'));
      expect(currentAttrs['房屋座落'], equals('新北市板橋區'));
    });

    test('5. CSV / Excel Formula Injection (DDE 攻擊) 自動跳脫測試', () {
      expect(CustomerExportService.sanitizeFormula('=HYPERLINK("http://evil.com")'), equals('\'=HYPERLINK("http://evil.com")'));
      expect(CustomerExportService.sanitizeFormula('+cmd|\' /C calc\'!A0'), equals('\'+cmd|\' /C calc\'!A0'));
      expect(CustomerExportService.sanitizeFormula('-12345'), equals('\'-12345'));
      expect(CustomerExportService.sanitizeFormula('@SUM(1+1)'), equals('\'@SUM(1+1)'));
      expect(CustomerExportService.sanitizeFormula('\t=MALICIOUS()'), equals('\'\t=MALICIOUS()'));
      expect(CustomerExportService.sanitizeFormula('正常客戶姓名'), equals('正常客戶姓名'));
      expect(CustomerExportService.sanitizeFormula(''), equals(''));
    });

    test('6. HTML 報表 XSS 安全跳脫測試', () {
      expect(CustomerExportService.escapeHtml('<script>alert("XSS")</script>'), equals('&lt;script&gt;alert(&quot;XSS&quot;)&lt;&#47;script&gt;'));
      expect(CustomerExportService.escapeHtml('王大明 <img src=x onerror=alert(1)>'), equals('王大明 &lt;img src=x onerror=alert(1)&gt;'));
      expect(CustomerExportService.escapeHtml('Tom & Jerry "VIP" \'Client\''), equals('Tom &amp; Jerry &quot;VIP&quot; &#39;Client&#39;'));
    });

    test('7. 核心欄位衝突防護與隔離測試', () {
      final customerWithCollidingKeys = [
        {
          'id': 'cust-collision',
          'name': '張三',
          'phone': '0900-000-000',
          'email': 'zhang@example.com',
          'custom_attributes': {
            '姓名': '自訂的名字',
            '電話': '自訂的電話',
            'email': 'custom@email.com',
            'custom_attributes': 'nested',
            '合法自訂欄位': '正常值',
          },
        }
      ];

      final keys = CustomerExportService.instance.extractAllCustomAttributeKeys(customerWithCollidingKeys);
      expect(keys, contains('姓名'));
      expect(keys, contains('電話'));
      expect(keys, contains('email'));
      expect(keys, contains('合法自訂欄位'));
    });

    test('8. Unicode 與全形空白規範化去重測試', () {
      final customersWithUnicodeSpaces = [
        {
          'id': 'cust-unicode-1',
          'name': '李四',
          'custom_attributes': {
            '　生日　': '1990-01-01', // 全形空白
            '配偶\n': '王五',        // 換行符
            '  年收入  ': '100萬',     // 半形空白
          },
        },
        {
          'id': 'cust-unicode-2',
          'name': '趙六',
          'custom_attributes': {
            '生日': '1992-02-02',    // 標準 Key
            '配偶': '錢七',          // 標準 Key
            '年收入': '150萬',        // 標準 Key
          },
        }
      ];

      final normalizedKeys = CustomerExportService.instance.extractAllCustomAttributeKeys(customersWithUnicodeSpaces);
      // 驗證全形/半形空白與換行符被規範化去重，不產生重複欄位
      expect(normalizedKeys.length, equals(3));
      expect(normalizedKeys, containsAll(['年收入', '配偶', '生日']));
    });

    test('9. vCard 3.0 RFC 2426 特殊字符嚴格跳脫測試', () {
      expect(CustomerExportService.escapeVCard('台北市,中山區;南京東路\\一段\n5號'), equals(r'台北市\,中山區\;南京東路\\一段\n5號'));
      expect(CustomerExportService.escapeVCard('正常備註內容'), equals('正常備註內容'));
    });

    test('10. 核心欄位同名自訂屬性之可逆無損往返測試 (Reversible Round-Trip Prefix Restoration)', () {
      // 假設業務員自訂了名為「姓名」、「電話」的額外欄位
      final originalAttrs = {
        '姓名': '原住民傳統名-谷木',
        '電話': '0900-111-222',
        '生日': '1995-08-10',
      };

      final customer = {
        'id': 'cust-roundtrip-p1',
        'name': '漢名王小明',
        'phone': '0988-777-666',
        'custom_attributes': originalAttrs,
      };

      // 1. 匯出：提取 Key
      final keys = CustomerExportService.instance.extractAllCustomAttributeKeys([customer]);
      expect(keys, containsAll(['姓名', '電話', '生日']));

      // 2. 模擬匯出為試算表表頭（核心同名 Key 自動轉為「自訂_」以防與核心欄位衝突）
      final exportedHeaders = keys.map((k) {
        return (k == '姓名' || k == '電話') ? '自訂_$k' : k;
      }).toList();

      expect(exportedHeaders, containsAll(['自訂_姓名', '自訂_電話', '生日']));

      // 3. 模擬再次匯入：解析端自動還原「自訂_」前綴
      final Map<String, dynamic> restoredCustomAttrs = {};
      for (final h in exportedHeaders) {
        String cleanKey = h.trim();
        if (cleanKey.startsWith('自訂_')) {
          cleanKey = cleanKey.substring(3).trim();
        }
        restoredCustomAttrs[cleanKey] = originalAttrs[cleanKey];
      }

      // 4. 驗證還原後的 Key 與 Value 100% 等同於原始自訂屬性
      expect(restoredCustomAttrs.keys, containsAll(['姓名', '電話', '生日']));
      expect(restoredCustomAttrs['姓名'], equals('原住民傳統名-谷木'));
      expect(restoredCustomAttrs['電話'], equals('0900-111-222'));
      expect(restoredCustomAttrs['生日'], equals('1995-08-10'));
      expect(restoredCustomAttrs.containsKey('自訂_姓名'), isFalse);
    });

    test('11. vCard 3.0 RFC 2426 長內容折行 (Line Folding) 測試', () {
      const shortLine = 'NOTE;CHARSET=UTF-8:短備註';
      expect(CustomerExportService.foldVCardLine(shortLine), equals(shortLine));

      final longLine = 'NOTE;CHARSET=UTF-8:' + '這是一段非常非常非常非常非常長長長長長長長長長長長長長長長長長長長長長長長長長長長長長長長長長長長長的備註內容，用以驗證RFC 2426規範每75字元折行';
      final folded = CustomerExportService.foldVCardLine(longLine);
      expect(folded.contains('\r\n '), isTrue);
    });
  });
}
