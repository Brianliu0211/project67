import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:desktop_drop/desktop_drop.dart';
import 'custom_toast.dart';
import '../services/app_settings.dart';

// Conditionally handle web download without breaking desktop/mobile analysis
import 'dart:html' as html if (dart.library.io) 'dart:io';

class BatchImportCustomersDialog extends StatefulWidget {
  final List<Map<String, dynamic>> existingCustomers;
  final Function(List<Map<String, dynamic>> importedCustomers, String duplicateStrategy) onImport;

  const BatchImportCustomersDialog({
    super.key,
    required this.existingCustomers,
    required this.onImport,
  });

  @override
  State<BatchImportCustomersDialog> createState() => _BatchImportCustomersDialogState();
}

class _BatchImportCustomersDialogState extends State<BatchImportCustomersDialog> {
  int _currentStep = 0; // 0: Select File, 1: Header Mapping, 2: Preview & Clean, 3: Completed
  bool _isDragging = false;

  String? _fileName;
  Uint8List? _fileBytes;
  List<List<dynamic>> _rawRows = [];
  List<String> _headers = [];

  // Mapping state (Header Index for each field, -1 means Not Mapped)
  int _nameColIndex = -1;
  int _nicknameColIndex = -1;
  int _phoneColIndex = -1;
  int _emailColIndex = -1;
  int _tagsColIndex = -1;
  int _notesColIndex = -1;

  // Flexible Strategy Toggles
  bool _mergeUnmappedToNotes = true;
  bool _convertCustomToTags = false;

  // Processed Data Preview list
  List<_ParsedCustomerRow> _parsedRows = [];

  // Duplicate Handling Strategy
  String _duplicateStrategy = 'overwrite'; // 'overwrite', 'skip', 'create_new'

  bool _isProcessing = false;
  bool _isPickingFile = false; // Mutex lock to prevent duplicate file picker calls

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    final dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 860,
        height: 680,
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(isDark, primaryColor, textColor, subTextColor, borderColor),
            _buildStepIndicator(isDark, primaryColor, textColor, subTextColor),
            Expanded(
              child: _buildStepContent(isDark, primaryColor, textColor, subTextColor, borderColor),
            ),
            _buildFooterNav(isDark, primaryColor, textColor, subTextColor, borderColor),
          ],
        ),
      ),
    );
  }

  // --- Header Bar ---
  Widget _buildHeader(bool isDark, Color primaryColor, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.file_upload_outlined, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '客戶 Excel / CSV 批次匯入中樞',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '支援彈性欄位語意對照、格式清洗、未對照欄位打包與重複比對對策',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: subTextColor),
            hoverColor: primaryColor.withOpacity(0.1),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step Progress Bar ---
  Widget _buildStepIndicator(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    final steps = ['選擇檔案', '欄位與對策設定', '資料預覽與檢核', '完成匯入'];
    final stepBg = isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      color: stepBg,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF10B981)
                        : isActive
                            ? primaryColor
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[index],
                  style: TextStyle(
                    color: isActive
                        ? primaryColor
                        : isDone
                            ? textColor
                            : subTextColor,
                    fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: isDone ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- Step Main Contents ---
  Widget _buildStepContent(bool isDark, Color primaryColor, Color textColor, Color subTextColor, Color borderColor) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text('正在高效解析試算表資料，請稍候...', style: TextStyle(color: subTextColor)),
          ],
        ),
      );
    }

    switch (_currentStep) {
      case 0:
        return _buildStep1FileSelection(isDark, primaryColor, textColor, subTextColor, borderColor);
      case 1:
        return _buildStep2HeaderMapping(isDark, primaryColor, textColor, subTextColor, borderColor);
      case 2:
        return _buildStep3PreviewAndValidation(isDark, primaryColor, textColor, subTextColor, borderColor);
      case 3:
        return _buildStep4Completed(isDark, primaryColor, textColor, subTextColor);
      default:
        return Container();
    }
  }

  // === STEP 1: FILE SELECTION & TEMPLATE DOWNLOAD ===
  Widget _buildStep1FileSelection(bool isDark, Color primaryColor, Color textColor, Color subTextColor, Color borderColor) {
    final boxBg = isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC);
    final infoBg = primaryColor.withOpacity(0.08);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '上傳客戶 Excel (.xlsx) 或 CSV 檔案',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              OutlinedButton.icon(
                onPressed: _downloadSampleTemplate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('下載標準 CSV 範本'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Upload Box with Drag and Drop Support
          Expanded(
            child: DropTarget(
              onDragEntered: (details) {
                setState(() {
                  _isDragging = true;
                });
              },
              onDragExited: (details) {
                setState(() {
                  _isDragging = false;
                });
              },
              onDragDone: (details) async {
                setState(() {
                  _isDragging = false;
                });
                if (details.files.isNotEmpty) {
                  final file = details.files.first;
                  final name = file.name;
                  final bytes = await file.readAsBytes();

                  setState(() {
                    _fileName = name;
                    _fileBytes = bytes;
                    _isProcessing = true;
                  });

                  final nameLower = name.toLowerCase();
                  if (nameLower.endsWith('.csv')) {
                    try {
                      _parseCsv(bytes);
                    } catch (_) {
                      _parseXlsx(bytes);
                    }
                  } else {
                    try {
                      _parseXlsx(bytes);
                    } catch (_) {
                      try {
                        _parseCsv(bytes);
                      } catch (_) {}
                    }
                  }

                  setState(() {
                    _isProcessing = false;
                  });

                  if (_rawRows.isEmpty) {
                    CustomToast.show(context, '試算表為空或格式無法自動辨識，請使用標準 .csv 或 .xlsx 檔', ToastType.warning);
                  } else {
                    CustomToast.show(context, '成功拖拽並讀取檔案：$name (${_rawRows.length} 列)', ToastType.success);
                  }
                }
              },
              child: GestureDetector(
                onTap: _pickFile,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? primaryColor.withOpacity(0.15)
                        : boxBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDragging
                          ? primaryColor
                          : _fileName != null
                              ? const Color(0xFF10B981)
                              : borderColor,
                      width: _isDragging ? 3 : 2,
                    ),
                    boxShadow: _isDragging
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isDragging
                            ? Icons.file_download_rounded
                            : _fileName != null
                                ? Icons.task_outlined
                                : Icons.cloud_upload_outlined,
                        size: 64,
                        color: _isDragging
                            ? primaryColor
                            : _fileName != null
                                ? const Color(0xFF10B981)
                                : primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isDragging
                            ? '鬆開滑鼠即可放上檔案！'
                            : _fileName ?? '將 CSV / XLSX 檔案拖曳至此，或點擊下方按鈕選取',
                        style: TextStyle(
                          color: _fileName != null ? textColor : subTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.folder_open, size: 20),
                        label: const Text('📂 選擇電腦檔案...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fileName != null
                            ? '已成功讀取 ${_rawRows.length} 列資料（含標頭）'
                            : '支援格式：.csv, .xlsx (即使用戶原本 Excel 欄位雜亂亦可自動語意對照)',
                        style: TextStyle(color: subTextColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tips Alert
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: infoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '提示：即使您原本在 Excel 裡使用了自訂欄位（如生日、配偶、舊保單等），下一步系統會自動將未對照的欄位打包整理至「客戶備註」，資料 100% 完整保留！',
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === STEP 2: HEADER MAPPING & STRATEGY SELECTION ===
  Widget _buildStep2HeaderMapping(bool isDark, Color primaryColor, Color textColor, Color subTextColor, Color borderColor) {
    final boxBg = isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. 對照欄位語意 (Mapping)',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '系統已自動為您對應常見欄位名稱，您可下拉手動微調映射關係：',
            style: TextStyle(color: subTextColor, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Grid Mapping Cards
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 3.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMappingCard('客戶姓名 *', _nameColIndex, (val) => setState(() => _nameColIndex = val), isDark, primaryColor, textColor, subTextColor, borderColor, isRequired: true),
              _buildMappingCard('綽號 / 稱呼', _nicknameColIndex, (val) => setState(() => _nicknameColIndex = val), isDark, primaryColor, textColor, subTextColor, borderColor),
              _buildMappingCard('電話號碼', _phoneColIndex, (val) => setState(() => _phoneColIndex = val), isDark, primaryColor, textColor, subTextColor, borderColor),
              _buildMappingCard('Email 信箱', _emailColIndex, (val) => setState(() => _emailColIndex = val), isDark, primaryColor, textColor, subTextColor, borderColor),
              _buildMappingCard('分類標籤', _tagsColIndex, (val) => setState(() => _tagsColIndex = val), isDark, primaryColor, textColor, subTextColor, borderColor),
              _buildMappingCard('客戶備註', _notesColIndex, (val) => setState(() => _notesColIndex = val), isDark, primaryColor, textColor, subTextColor, borderColor),
            ],
          ),

          const SizedBox(height: 28),
          Divider(color: borderColor),
          const SizedBox(height: 16),

          Text(
            '2. 格式相異與彈性處理策略 (Flexible Fallbacks)',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Strategy Checkboxes
          Container(
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _mergeUnmappedToNotes,
                  onChanged: (v) => setState(() => _mergeUnmappedToNotes = v ?? true),
                  activeColor: primaryColor,
                  title: Text('自動將未映射之欄位打包併入客戶備註 (建議開啟)', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('例如：原表格有「生日、配偶、舊保單」，將自動整理為『【匯入補充資訊】• 生日: 1985-05-20』併入備註，資料不遺失。', style: TextStyle(color: subTextColor, fontSize: 12)),
                ),
                Divider(color: borderColor, height: 1),
                CheckboxListTile(
                  value: _convertCustomToTags,
                  onChanged: (v) => setState(() => _convertCustomToTags = v ?? false),
                  activeColor: primaryColor,
                  title: Text('將未對照之屬性欄位轉換為分類標籤 (Tags)', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('例如：將原表格的「客戶等級: VIP」、「地區: 台北」自動抽出作為客戶之標籤。', style: TextStyle(color: subTextColor, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            '3. 重複客戶比對處置策略 (Deduplication)',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildStrategyRadio('overwrite', '覆蓋舊資料', '同電話/姓名時，以新資料更新客戶', isDark, primaryColor, textColor, subTextColor, borderColor),
              const SizedBox(width: 12),
              _buildStrategyRadio('skip', '跳過不匯入', '若已存在則保留原資料，不重覆新增', isDark, primaryColor, textColor, subTextColor, borderColor),
              const SizedBox(width: 12),
              _buildStrategyRadio('create_new', '強制新建筆數', '忽視重複直接建立為獨立客戶', isDark, primaryColor, textColor, subTextColor, borderColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMappingCard(
    String label,
    int selectedCol,
    ValueChanged<int> onChanged,
    bool isDark,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
    Color borderColor, {
    bool isRequired = false,
  }) {
    final boxBg = isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC);
    final dropDownBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selectedCol != -1 ? primaryColor : borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: isRequired ? const Color(0xFFF43F5E) : textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedCol,
                dropdownColor: dropDownBg,
                isExpanded: true,
                style: TextStyle(color: primaryColor, fontSize: 13),
                items: [
                  DropdownMenuItem(value: -1, child: Text('(不對照 / 留空)', style: TextStyle(color: subTextColor))),
                  ...List.generate(_headers.length, (idx) {
                    return DropdownMenuItem(
                      value: idx,
                      child: Text(
                        'Column ${idx + 1}: ${_headers[idx]}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyRadio(
    String value,
    String title,
    String subtitle,
    bool isDark,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    final isSelected = _duplicateStrategy == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _duplicateStrategy = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.12) : (isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? primaryColor : borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: isSelected ? primaryColor : subTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? primaryColor : textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: subTextColor, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === STEP 3: PREVIEW & CLEANING GALLERY ===
  Widget _buildStep3PreviewAndValidation(bool isDark, Color primaryColor, Color textColor, Color subTextColor, Color borderColor) {
    final validCount = _parsedRows.where((r) => r.isValid).length;
    final cleanedCount = _parsedRows.where((r) => r.isCleaned).length;
    final invalidCount = _parsedRows.where((r) => !r.isValid).length;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat chips
          Row(
            children: [
              _buildStatChip('總預覽筆數', '${_parsedRows.length} 筆', primaryColor, isDark),
              const SizedBox(width: 12),
              _buildStatChip('🟢 驗證通過', '$validCount 筆', const Color(0xFF10B981), isDark),
              const SizedBox(width: 12),
              _buildStatChip('🟡 已正規化/補充備註', '$cleanedCount 筆', const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 12),
              _buildStatChip('🔴 缺姓名無效檔', '$invalidCount 筆', const Color(0xFFF43F5E), isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Data Table Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                    dataRowHeight: 52,
                    columns: [
                      DataColumn(label: Text('列數', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('狀態', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('客戶姓名', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('電話號碼 (自動正規化)', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Email', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('分類標籤 (Tags)', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('自動整理之備註 (含未映射欄位)', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                    ],
                    rows: _parsedRows.map((row) {
                      return DataRow(
                        cells: [
                          DataCell(Text('#${row.rowIndex}', style: TextStyle(color: subTextColor))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: !row.isValid
                                    ? const Color(0xFFF43F5E).withOpacity(0.15)
                                    : row.isCleaned
                                        ? const Color(0xFFF59E0B).withOpacity(0.15)
                                        : const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                !row.isValid
                                    ? '無效 (缺姓名)'
                                    : row.isCleaned
                                        ? '已整理備註'
                                        : '完美符合',
                                style: TextStyle(
                                  color: !row.isValid
                                      ? const Color(0xFFF43F5E)
                                      : row.isCleaned
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(row.name.isNotEmpty ? row.name : '(空缺)', style: TextStyle(color: textColor, fontWeight: FontWeight.w600))),
                          DataCell(Text(row.phone, style: TextStyle(color: primaryColor))),
                          DataCell(Text(row.email, style: TextStyle(color: textColor))),
                          DataCell(
                            Wrap(
                              spacing: 4,
                              children: row.tags.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(t, style: TextStyle(color: primaryColor, fontSize: 10)),
                                );
                              }).toList(),
                            ),
                          ),
                          DataCell(
                            Tooltip(
                              message: row.notes,
                              child: SizedBox(
                                width: 200,
                                child: Text(
                                  row.notes,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: subTextColor, fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 12)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // === STEP 4: SUCCESS SUMMARY ===
  Widget _buildStep4Completed(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    final validRows = _parsedRows.where((r) => r.isValid).toList();
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.15),
            ),
            child: const Icon(Icons.check_circle_rounded, size: 80, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 24),
          Text(
            '準備就緒！即將匯入 ${validRows.length} 筆客戶資料',
            style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '重複資料比對對策：${_duplicateStrategy == 'overwrite' ? '遇到同電話/姓名自動覆蓋舊紀錄' : _duplicateStrategy == 'skip' ? '遇到同電話/姓名自動跳過' : '忽視重複建立獨立資料'}',
            style: TextStyle(color: subTextColor, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: primaryColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  '系統已完成欄位洗淨、全形數字轉半形與未映射欄位 100% 備註打包',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Footer Navigation ---
  Widget _buildFooterNav(bool isDark, Color primaryColor, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep--;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: subTextColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: Text(_currentStep == 0 ? '取消' : '上一步'),
          ),
          Row(
            children: [
              if (_currentStep < 3)
                ElevatedButton.icon(
                  onPressed: _fileName == null && _currentStep == 0
                      ? null
                      : () {
                          if (_currentStep == 0) {
                            if (_rawRows.isEmpty) {
                              CustomToast.show(context, '請先選取有效之 CSV 或 XLSX 檔案', ToastType.warning);
                              return;
                            }
                          }
                          if (_currentStep == 1) {
                            if (_nameColIndex == -1) {
                              CustomToast.show(context, '必須設定「客戶姓名」之對照欄位！', ToastType.warning);
                              return;
                            }
                            _processParsedData();
                          }
                          setState(() {
                            _currentStep++;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('下一步', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton.icon(
                  onPressed: _executeFinalImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('確認執行批次匯入', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Logic Helpers ---
  Future<void> _pickFile() async {
    if (_isPickingFile) return; // Prevent double pick file picker exception
    setState(() {
      _isPickingFile = true;
    });

    try {
      if (kIsWeb) {
        // Native Web File Upload Input Element Fallback
        final uploadInput = html.FileUploadInputElement();
        uploadInput.accept = '.csv,.xlsx';
        uploadInput.click();

        await uploadInput.onChange.first;
        if (uploadInput.files != null && uploadInput.files!.isNotEmpty) {
          final file = uploadInput.files!.first;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);

          await reader.onLoadEnd.first;
          final bytes = reader.result as Uint8List;

          setState(() {
            _fileName = file.name;
            _fileBytes = bytes;
            _isProcessing = true;
          });

          final nameLower = file.name.toLowerCase();
          if (nameLower.endsWith('.csv')) {
            try {
              _parseCsv(bytes);
            } catch (_) {
              _parseXlsx(bytes);
            }
          } else {
            try {
              _parseXlsx(bytes);
            } catch (_) {
              try {
                _parseCsv(bytes);
              } catch (_) {}
            }
          }

          setState(() {
            _isProcessing = false;
          });

          if (_rawRows.isEmpty) {
            if (mounted) CustomToast.show(context, '試算表為空或格式無法自動辨識，請使用標準 .csv 或 .xlsx 檔', ToastType.warning);
          } else {
            if (mounted) CustomToast.show(context, '已成功讀取檔案：${file.name} (${_rawRows.length} 列)', ToastType.success);
          }
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv', 'xlsx'],
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          final bytes = file.bytes;
          if (bytes != null) {
            setState(() {
              _fileName = file.name;
              _fileBytes = bytes;
              _isProcessing = true;
            });

            final nameLower = file.name.toLowerCase();
            if (nameLower.endsWith('.csv')) {
              try {
                _parseCsv(bytes);
              } catch (_) {
                _parseXlsx(bytes);
              }
            } else {
              try {
                _parseXlsx(bytes);
              } catch (_) {
                try {
                  _parseCsv(bytes);
                } catch (_) {}
              }
            }

            setState(() {
              _isProcessing = false;
            });

            if (_rawRows.isEmpty) {
              if (mounted) CustomToast.show(context, '試算表為空或格式無法自動辨識，請使用標準 .csv 或 .xlsx 檔', ToastType.warning);
            } else {
              if (mounted) CustomToast.show(context, '已成功讀取檔案：${file.name} (${_rawRows.length} 列)', ToastType.success);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, '讀取檔案失敗或已取消', ToastType.warning);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isPickingFile = false;
        });
      }
    }
  }

  void _parseCsv(Uint8List bytes) {
    String csvString;
    try {
      csvString = utf8.decode(bytes);
    } catch (_) {
      // Big5 or ANSI fallback decoder
      csvString = String.fromCharCodes(bytes);
    }

    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(csvString);
    if (rows.isNotEmpty) {
      _rawRows = rows;
      _headers = rows.first.map((e) => e.toString().trim()).toList();
      _autoDetectHeaders();
    }
  }

  void _parseXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isNotEmpty) {
      final table = excel.tables[excel.tables.keys.first];
      if (table != null && table.rows.isNotEmpty) {
        _rawRows = table.rows.map((r) => r.map((cell) => cell?.value?.toString() ?? '').toList()).toList();
        _headers = _rawRows.first.map((e) => e.toString().trim()).toList();
        _autoDetectHeaders();
      }
    }
  }

  void _autoDetectHeaders() {
    for (int i = 0; i < _headers.length; i++) {
      final h = _headers[i].toLowerCase();
      if (h.contains('姓名') || h.contains('客戶名') || h.contains('name')) {
        _nameColIndex = i;
      } else if (h.contains('稱呼') || h.contains('綽號') || h.contains('nickname')) {
        _nicknameColIndex = i;
      } else if (h.contains('電話') || h.contains('手機') || h.contains('phone') || h.contains('tel')) {
        _phoneColIndex = i;
      } else if (h.contains('信箱') || h.contains('email') || h.contains('郵件')) {
        _emailColIndex = i;
      } else if (h.contains('標籤') || h.contains('tag') || h.contains('分類')) {
        _tagsColIndex = i;
      } else if (h.contains('備註') || h.contains('note') || h.contains('說明')) {
        _notesColIndex = i;
      }
    }
  }

  void _processParsedData() {
    _parsedRows.clear();

    final dataRows = _rawRows.skip(1).toList();
    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];

      String name = _getValue(row, _nameColIndex);
      String nickname = _getValue(row, _nicknameColIndex);
      String rawPhone = _getValue(row, _phoneColIndex);
      String email = _getValue(row, _emailColIndex);
      String rawTags = _getValue(row, _tagsColIndex);
      String notes = _getValue(row, _notesColIndex);

      // Fullwidth to Halfwidth normalize
      String cleanedPhone = _cleanPhone(rawPhone);

      List<String> tags = [];
      if (rawTags.isNotEmpty) {
        tags = rawTags.split(RegExp(r'[,;\s/]+')).where((t) => t.trim().isNotEmpty).toList();
      }

      List<String> unmappedDetails = [];
      for (int c = 0; c < _headers.length; c++) {
        if (c != _nameColIndex &&
            c != _nicknameColIndex &&
            c != _phoneColIndex &&
            c != _emailColIndex &&
            c != _tagsColIndex &&
            c != _notesColIndex) {
          final val = _getValue(row, c);
          if (val.isNotEmpty) {
            final colName = _headers[c];
            unmappedDetails.add('• $colName: $val');
            if (_convertCustomToTags) {
              tags.add('$colName: $val');
            }
          }
        }
      }

      bool isCleaned = false;
      if (unmappedDetails.isNotEmpty && _mergeUnmappedToNotes) {
        isCleaned = true;
        final unmappedBlock = '【匯入補充資訊】\n${unmappedDetails.join('\n')}';
        notes = notes.isNotEmpty ? '$notes\n\n$unmappedBlock' : unmappedBlock;
      }

      bool isValid = name.isNotEmpty;

      _parsedRows.add(_ParsedCustomerRow(
        rowIndex: i + 2, // 1-indexed row number after header
        name: name,
        nickname: nickname,
        phone: cleanedPhone,
        email: email,
        tags: tags,
        notes: notes,
        isValid: isValid,
        isCleaned: isCleaned,
      ));
    }
  }

  String _cleanPhone(String input) {
    if (input.isEmpty) return '';
    // Fullwidth numbers to halfwidth
    String normalized = input.replaceAll('０', '0')
        .replaceAll('１', '1')
        .replaceAll('２', '2')
        .replaceAll('３', '3')
        .replaceAll('４', '4')
        .replaceAll('５', '5')
        .replaceAll('６', '6')
        .replaceAll('７', '7')
        .replaceAll('８', '8')
        .replaceAll('９', '9')
        .replaceAll('—', '-')
        .replaceAll('－', '-');

    return normalized.trim();
  }

  String _getValue(List<dynamic> row, int index) {
    if (index >= 0 && index < row.length) {
      return row[index].toString().trim();
    }
    return '';
  }

  void _downloadSampleTemplate() {
    const csvContent = '\uFEFF客戶姓名,綽號/稱呼,電話號碼,Email信箱,分類標籤,客戶備註,自訂欄位(生日),自訂欄位(地區)\n'
        '陳小明,小明,0912-345-678,ming@example.com,"VIP, 車險",喜好高科技保單,1990-05-12,台北市\n'
        '林美麗,阿麗,0987-654-321,mary@example.com,"壽險, 定期險",需規劃年金險,1985-11-20,新北市\n';

    if (kIsWeb) {
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '客戶批次匯入範本_保險助手.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
      CustomToast.show(context, '已成功下載「標準 CSV 範本檔案」！', ToastType.success);
    } else {
      CustomToast.show(context, '範本內容已就緒', ToastType.warning);
    }
  }

  void _executeFinalImport() {
    final validRows = _parsedRows.where((r) => r.isValid).toList();
    final List<Map<String, dynamic>> importPayload = validRows.map((r) {
      return {
        'name': r.name,
        'nickname': r.nickname,
        'phone': r.phone,
        'email': r.email,
        'tags': r.tags,
        'notes': r.notes,
      };
    }).toList();

    widget.onImport(importPayload, _duplicateStrategy);
    Navigator.of(context).pop();
  }
}

class _ParsedCustomerRow {
  final int rowIndex;
  final String name;
  final String nickname;
  final String phone;
  final String email;
  final List<String> tags;
  final String notes;
  final bool isValid;
  final bool isCleaned;

  _ParsedCustomerRow({
    required this.rowIndex,
    required this.name,
    required this.nickname,
    required this.phone,
    required this.email,
    required this.tags,
    required this.notes,
    required this.isValid,
    required this.isCleaned,
  });
}
