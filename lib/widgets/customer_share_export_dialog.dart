import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/customer_export_service.dart';
import 'custom_toast.dart';

/// 客戶資料分享與匯出微動畫彈窗 (Customer Share & Export Micro-Animation Dialog)
class CustomerShareExportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  final String scopeDescription; // e.g. "已選取的 3 位客戶" or "搜尋篩選之 8 位客戶" or "全部 24 位客戶"

  const CustomerShareExportDialog({
    super.key,
    required this.customers,
    required this.scopeDescription,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> customers,
    required String scopeDescription,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CustomerShareExportDialog',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedValue = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack).value;
        return Transform.scale(
          scale: curvedValue,
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: CustomerShareExportDialog(
              customers: customers,
              scopeDescription: scopeDescription,
            ),
          ),
        );
      },
    );
  }

  @override
  State<CustomerShareExportDialog> createState() => _CustomerShareExportDialogState();
}

class _CustomerShareExportDialogState extends State<CustomerShareExportDialog> {
  bool _isExporting = false;
  String _exportingType = '';

  Future<void> _handleExport(String type, Future<void> Function() exportAction, String successMsg) async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _exportingType = type;
    });

    try {
      await exportAction();
      if (mounted) {
        Navigator.of(context).pop();
        CustomToast.show(context, successMsg, ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '匯出失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportingType = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final dynamicKeys = CustomerExportService.instance.extractAllCustomAttributeKeys(widget.customers);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Scope Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.ios_share_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '匯出與分享資料庫',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '🎯 ${widget.scopeDescription} (${widget.customers.length} 筆)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          if (dynamicKeys.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '✨ 包含 ${dynamicKeys.length} 項自訂欄位',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: subTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 16),

            // Format Options Grid
            _buildExportOptionCard(
              title: '📊 匯出 Excel 試算表 (.xlsx)',
              subtitle: '完整多欄結構化試算表，100% 保留所有自訂擴充屬性',
              badge: '微軟 Excel / Google 試算表通用',
              color: const Color(0xFF10B981),
              icon: Icons.table_chart_rounded,
              isProcessing: _isExporting && _exportingType == 'excel',
              isDark: isDark,
              onTap: () => _handleExport(
                'excel',
                () => CustomerExportService.instance.exportToExcel(customers: widget.customers),
                '✅ 已成功生成並下載 Excel (.xlsx) 試算表！',
              ),
            ),
            const SizedBox(height: 10),

            _buildExportOptionCard(
              title: '📑 匯出 CSV 試算表 (.csv)',
              subtitle: '前置 UTF-8 BOM 繁中防亂碼標準格式，輕量且各工具通用',
              badge: 'UTF-8 BOM 繁中無損',
              color: const Color(0xFF0EA5E9),
              icon: Icons.grid_on_rounded,
              isProcessing: _isExporting && _exportingType == 'csv',
              isDark: isDark,
              onTap: () => _handleExport(
                'csv',
                () => CustomerExportService.instance.exportToCsv(customers: widget.customers),
                '✅ 已成功生成並下載 CSV (.csv) 試算表！',
              ),
            ),
            const SizedBox(height: 10),

            _buildExportOptionCard(
              title: '📇 匯出 vCard 通訊錄 (.vcf)',
              subtitle: '標準 RFC 2426 通訊錄名片，手機 (iOS/Android) 點擊一鍵直接匯入',
              badge: '手機/電腦通訊錄直接導入',
              color: const Color(0xFF8B5CF6),
              icon: Icons.contacts_rounded,
              isProcessing: _isExporting && _exportingType == 'vcard',
              isDark: isDark,
              onTap: () => _handleExport(
                'vcard',
                () => CustomerExportService.instance.exportToVCard(customers: widget.customers),
                '✅ 已成功生成 vCard (.vcf) 檔案！點擊可直接匯入手機通訊錄。',
              ),
            ),
            const SizedBox(height: 10),

            _buildExportOptionCard(
              title: '📄 匯出客戶總覽報表 (PDF / 列印)',
              subtitle: '生成具備排版與統計卡片之網頁報表，支援瀏覽器列印或另存 PDF',
              badge: '會議報告 / 另存 PDF',
              color: const Color(0xFFEC4899),
              icon: Icons.picture_as_pdf_rounded,
              isProcessing: _isExporting && _exportingType == 'html',
              isDark: isDark,
              onTap: () => _handleExport(
                'html',
                () => CustomerExportService.instance.exportToPrintableReport(customers: widget.customers),
                '✅ 已成功生成客戶檔案總覽報表！可直接列印或另存為 PDF。',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptionCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required IconData icon,
    required bool isProcessing,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.05);
    final cardBorder = isDark ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.2);

    return InkWell(
      onTap: _isExporting ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isProcessing
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
                    )
                  : Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
