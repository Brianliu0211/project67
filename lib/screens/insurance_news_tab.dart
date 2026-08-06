import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_settings.dart';
import '../widgets/custom_toast.dart';

class InsuranceNewsTopic {
  final String id;
  final String topicTitle;
  final String category;
  final String? mainImageUrl;
  final String aiSummary;
  final String? dailyTrend;
  final String? dailyOverview;
  final String publishDate;
  final List<InsuranceNewsArticle> articles;

  InsuranceNewsTopic({
    required this.id,
    required this.topicTitle,
    required this.category,
    this.mainImageUrl,
    required this.aiSummary,
    this.dailyTrend,
    this.dailyOverview,
    required this.publishDate,
    required this.articles,
  });

  factory InsuranceNewsTopic.fromJson(Map<String, dynamic> json) {
    var rawArticles = json['insurance_news_articles'] as List<dynamic>? ?? [];
    List<InsuranceNewsArticle> articlesList = rawArticles
        .map((a) => InsuranceNewsArticle.fromJson(a as Map<String, dynamic>))
        .toList();

    return InsuranceNewsTopic(
      id: json['id'] as String,
      topicTitle: json['topic_title'] as String? ?? '新聞頭條話題',
      category: json['category'] as String? ?? '保險焦點',
      mainImageUrl: json['main_image_url'] as String?,
      aiSummary: json['ai_summary'] as String? ?? '無摘要內容',
      dailyTrend: json['daily_trend'] as String?,
      dailyOverview: json['daily_overview'] as String?,
      publishDate: json['publish_date'] as String? ?? '',
      articles: articlesList,
    );
  }
}

class InsuranceNewsArticle {
  final String id;
  final String topicId;
  final String title;
  final String sourceName;
  final String sourceUrl;
  final String articleSummary;
  final String? publishedAt;
  final bool isPrimary;

  InsuranceNewsArticle({
    required this.id,
    required this.topicId,
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    required this.articleSummary,
    this.publishedAt,
    required this.isPrimary,
  });

  factory InsuranceNewsArticle.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['article_summary'] as String?;
    final titleText = json['title'] as String? ?? '新聞標題';
    final hasValidSummary = rawSummary != null && rawSummary.trim().isNotEmpty && rawSummary != titleText;

    return InsuranceNewsArticle(
      id: json['id'] as String? ?? '',
      topicId: json['topic_id'] as String? ?? '',
      title: titleText,
      sourceName: json['source_name'] as String? ?? '新聞來源',
      sourceUrl: json['source_url'] as String? ?? '',
      articleSummary: hasValidSummary
          ? rawSummary!
          : '本篇報導詳細記錄了「$titleText」相關之金融保險市場脈動、監管政策走向與保戶權益分析。您亦可點擊下方按鈕連結至外部原媒體網站閱讀全文報導。',
      publishedAt: json['published_at'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

// 零延遲順滑懸停陰影按鈕 (比照行事曆平滑微動畫感)
class _SmoothHoverButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color shadowColor;
  final BorderSide? borderSide;

  const _SmoothHoverButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.shadowColor,
    this.borderSide,
  }) : super(key: key);

  @override
  State<_SmoothHoverButton> createState() => _SmoothHoverButtonState();
}

class _SmoothHoverButtonState extends State<_SmoothHoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: widget.borderSide != null ? Border.fromBorderSide(widget.borderSide!) : null,
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor.withOpacity(_isHovered ? 0.35 : 0.1),
                blurRadius: _isHovered ? 12 : 4,
                spreadRadius: _isHovered ? 1 : 0,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 8),
              DefaultTextStyle(
                style: TextStyle(
                  color: widget.foregroundColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                child: widget.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InsuranceNewsTab extends StatefulWidget {
  const InsuranceNewsTab({Key? key}) : super(key: key);

  @override
  State<InsuranceNewsTab> createState() => _InsuranceNewsTabState();
}

class _InsuranceNewsTabState extends State<InsuranceNewsTab> {
  bool _isLoading = false;
  List<InsuranceNewsTopic> _topics = [];

  @override
  void initState() {
    super.initState();
    _fetchDailyNews();
  }

  Future<void> _fetchDailyNews() async {
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('insurance_news_topics')
          .select('*, insurance_news_articles(*)')
          .order('created_at', ascending: false)
          .limit(10);

      if (response != null && (response as List).isNotEmpty) {
        final loadedTopics = (response as List)
            .map((json) => InsuranceNewsTopic.fromJson(json))
            .toList();

        // 依據話題標題進行前端去重防護，確保不重複顯示相同話題卡片
        final Map<String, InsuranceNewsTopic> uniqueTopicMap = {};
        for (var topic in loadedTopics) {
          if (!uniqueTopicMap.containsKey(topic.topicTitle.trim())) {
            uniqueTopicMap[topic.topicTitle.trim()] = topic;
          }
        }

        setState(() {
          _topics = uniqueTopicMap.values.toList();
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('讀取保險新聞失敗，使用預設展示範例數據: $e');
    }

    _loadMockData();
  }

  void _loadMockData() {
    final mockPrimaryTime = DateTime.now().subtract(const Duration(hours: 3)).toIso8601String();
    
    setState(() {
      _topics = [
        InsuranceNewsTopic(
          id: 'demo-topic-1',
          topicTitle: '醫療險實支實付新制上路與損害防阻原則落實',
          category: '法規政策',
          aiSummary: '金管會推動實支實付醫療險新制正式生效，全面落實損害防阻原則。壽險公司已完成全系列實支實付保單結構調整，未來保戶投保多張實支實付險將受核保限制。業務員在協助客戶規劃與理賠申請時，需特別注意新舊保單條款適用時點與副本理賠機制之差異。',
          dailyTrend: '從今日新聞可看出，主管機關正加速推動實支實付醫療險損害防阻與長照險商品結構轉型。',
          dailyOverview: '今日台灣保險市場受金管會保險局多項新制正式生效影響，壽險業全面進行商品結構與核保機制調整。實支實付醫療險正本理賠試行制度引起保戶與業務員高度關注，未來保單設計將更著重於損害防阻與健康促進。同時，各大金控與產壽險公司亦紛紛推出高CP值長照與零工族意外保障專案，展現極高的市場適應力。',
          publishDate: DateTime.now().toIso8601String().split('T')[0],
          articles: [
            InsuranceNewsArticle(
              id: 'a1',
              topicId: 'demo-topic-1',
              title: '實支實付新制今正式上路！壽險業產品全面下架調整',
              sourceName: '經濟日報',
              sourceUrl: 'https://news.google.com',
              articleSummary: '主管機關實支實付新制今日生效，壽險公司配合政策將舊有副本理賠商品全面停售，改以損害防阻為核心之新保單上架，確保保戶理賠回歸填補實際醫療費用損失本質。',
              publishedAt: mockPrimaryTime,
              isPrimary: true,
            ),
            InsuranceNewsArticle(
              id: 'a2',
              topicId: 'demo-topic-1',
              title: '醫療險副本理賠走入歷史？專家深入分析保戶三招權益保障',
              sourceName: 'Yahoo新聞',
              sourceUrl: 'https://news.google.com',
              articleSummary: '針對實支實付新制上路後保戶常見的疑惑，理賠專家指出既有舊保單不受溯及既往影響，新投保案件則須遵循正本理賠原則，建議業務代表協助保戶定期檢視既有保障額度。',
              publishedAt: mockPrimaryTime,
              isPrimary: false,
            ),
            InsuranceNewsArticle(
              id: 'a3',
              topicId: 'demo-topic-1',
              title: '金管會保險局宣導實支實付正本理賠試行要點與宣導事項',
              sourceName: '鏡週刊 Mirror Media',
              sourceUrl: 'https://news.google.com',
              articleSummary: '保險局召開記者會說明新制實施注意事項，強調壽險公會已建立配套機制，防範重複投保帶來的道德風險，並期許保險業者持續優化理賠給付服務流程。',
              publishedAt: mockPrimaryTime,
              isPrimary: false,
            ),
          ],
        ),
        InsuranceNewsTopic(
          id: 'demo-topic-2',
          topicTitle: '長照險與外送員專屬意外險銷售熱度升溫',
          category: '產品趨勢',
          aiSummary: '隨著高齡化社會加劇及零工經濟崛起，各大產壽險公司紛紛推出高CP值長照險與零工族專屬外送意外綜合險。最新市場數據顯示，2026年第三季長照保單投保率成長逾二成，業者更提供健康促進折抵保費機制，成為近期業務拜訪的熱門商品話題。',
          dailyTrend: '從今日新聞可看出，主管機關正加速推動實支實付醫療險損害防阻與長照險商品結構轉型。',
          dailyOverview: '今日台灣保險市場受金管會保險局多項新制正式生效影響，壽險業全面進行商品結構與核保機制調整。實支實付醫療險正本理賠試行制度引起保戶與業務員高度關注，未來保單設計將更著重於損害防阻與健康促進。同時，各大金控與產壽險公司亦紛紛推出高CP值長照與零工族意外保障專案，展現極高的市場適應力。',
          publishDate: DateTime.now().toIso8601String().split('T')[0],
          articles: [
            InsuranceNewsArticle(
              id: 'a4',
              topicId: 'demo-topic-2',
              title: '超高齡社會衝擊！高性價比長照險投保率創年度新高',
              sourceName: '工商時報',
              sourceUrl: 'https://news.google.com',
              articleSummary: '因應長照需求高漲，壽險業者推出具備分期給付與實物給付雙軌機制的長照終身險，結合健檢指數給付保費折扣，帶動業績大幅躍升。',
              publishedAt: mockPrimaryTime,
              isPrimary: true,
            ),
            InsuranceNewsArticle(
              id: 'a5',
              topicId: 'demo-topic-2',
              title: '外送平台合作專案意外險上架 打造碎粒化保障體驗',
              sourceName: '鉅亨網',
              sourceUrl: 'https://news.google.com',
              articleSummary: '產險公司與零工平台跨界合作，提供按次或按日扣款的碎粒化意外險，為高風險外送員提供實時傷害醫療與責任保障。',
              publishedAt: mockPrimaryTime,
              isPrimary: false,
            ),
          ],
        ),
      ];
      _isLoading = false;
    });
  }

  Future<void> _launchExternalUrl(String urlStr) async {
    if (urlStr.isEmpty) {
      CustomToast.show(context, '此新聞未提供外部連結', ToastType.warning);
      return;
    }
    final Uri uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        CustomToast.show(context, '無法開啟外部新聞連結', ToastType.warning);
      }
    } catch (e) {
      CustomToast.show(context, '連結跳轉異常 (原始網站可能已調整): $e', ToastType.error);
    }
  }

  String _formatUpdateTime(String? dateStr) {
    if (dateStr != null && dateStr.isNotEmpty) {
      if (dateStr.contains('T')) {
        final parts = dateStr.split('T');
        final date = parts[0];
        final timeParts = parts[1].split(':');
        if (timeParts.length >= 2) {
          return '$date ${timeParts[0]}:${timeParts[1]}';
        }
        return '$date 06:00';
      }
      return '$dateStr 06:00';
    }
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '${now.year}-$month-$day $hour:$min';
  }

  // 1. 今日產業大勢與總覽 Modal (統一 650x540 尺寸，右上角標註詳細更新時間，動態主題色)
  void _showDailyOverviewModal(bool isDark, Color primaryColor) {
    final firstTopic = _topics.isNotEmpty ? _topics.first : null;
    final trendText = firstTopic?.dailyTrend ?? '從今日新聞可看出，主管機關正積極引導保險業回歸保障本質，推動實支實付新制與外售商品轉型。';
    final overviewText = firstTopic?.dailyOverview ?? '今日台灣金融保險市場熱點聚焦於金管會保險局新制施行細則、實支實付醫療險正本理賠試行要點，以及各大壽險公司因應高齡化社會推動之長照與健康促進保單。業務員宜把握最新政策動向，即時為客戶提供最切合需求之保障規劃。';
    final updateTime = _formatUpdateTime(firstTopic?.publishDate);

    showDialog(
      context: context,
      builder: (ctx) {
        final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final trendBg = isDark ? const Color(0xFF1F2937) : primaryColor.withOpacity(0.08);
        final contentBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF9FAFB);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: bgColor,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 540),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.auto_awesome, color: primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '✨ 今日產業大勢與新聞總覽',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '更新時間：$updateTime',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '由 AI 自動為您綜整全網當日權威新聞與產業脈動',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: trendBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.trending_up, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          trendText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.45,
                            color: isDark ? Colors.cyanAccent : primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: contentBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        overviewText,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.65,
                          letterSpacing: 0.2,
                          color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('閱讀完畢', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. 點擊單篇新聞對話框
  void _showSingleArticleModal(InsuranceNewsArticle article, bool isDark, Color primaryColor) {
    showDialog(
      context: context,
      builder: (ctx) {
        final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final summaryBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: bgColor,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 540),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.sourceName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    if (article.isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '封面頭條',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.cyanAccent : Colors.teal,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SelectableText(
                  article.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: summaryBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.article_outlined, size: 18, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                '單篇新聞重點摘要',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.cyanAccent : primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            article.articleSummary,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.65,
                              letterSpacing: 0.2,
                              color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('返回列表'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _launchExternalUrl(article.sourceUrl);
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('🔗 前往媒體原網址閱讀全文'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. 彈出「瀏覽相關媒體報導」 Modal Dialog
  void _showAllArticlesModal(InsuranceNewsTopic topic, bool isDark, Color primaryColor) {
    showDialog(
      context: context,
      builder: (ctx) {
        final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final cardBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: bgColor,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 540),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.newspaper, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '相關媒體報導清單',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  topic.topicTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: topic.articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final article = topic.articles[index];
                      return Material(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showSingleArticleModal(article, isDark, primaryColor);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: article.isPrimary
                                        ? primaryColor.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    article.sourceName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: article.isPrimary
                                          ? primaryColor
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    article.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right, size: 20, color: primaryColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. 彈出「💡 AI 新聞重點摘要」 Modal Dialog
  void _showAiSummaryModal(InsuranceNewsTopic topic, bool isDark, Color primaryColor) {
    showDialog(
      context: context,
      builder: (ctx) {
        final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final summaryBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: bgColor,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 540),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI 話題重點摘要',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  topic.topicTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.cyanAccent : primaryColor,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: summaryBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        topic.aiSummary,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.65,
                          letterSpacing: 0.2,
                          color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('我知道了', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頁面頂頭選單列 (右上角 ✨ 今日產業大勢與總覽 按鈕)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.newspaper_outlined, size: 26, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(
                      '今日新聞頭條',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                // 右上角按鈕：✨ 今日產業大勢與總覽 (使用平滑陰影微動畫按鈕)
                _SmoothHoverButton(
                  onPressed: () => _showDailyOverviewModal(isDark, primaryColor),
                  icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  label: const Text('✨ 今日產業大勢與總覽'),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shadowColor: primaryColor,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 新聞話題列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _topics.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.feed_outlined, size: 64, color: subTextColor),
                              const SizedBox(height: 12),
                              Text('今日尚無新聞主題', style: TextStyle(color: subTextColor, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _topics.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 20),
                          itemBuilder: (context, index) {
                            final topic = _topics[index];
                            final primaryArticle = topic.articles.firstWhere(
                              (a) => a.isPrimary,
                              orElse: () => topic.articles.isNotEmpty
                                  ? topic.articles.first
                                  : InsuranceNewsArticle(
                                      id: '',
                                      topicId: topic.id,
                                      title: topic.topicTitle,
                                      sourceName: '權威媒體',
                                      sourceUrl: '',
                                      articleSummary: topic.aiSummary,
                                      isPrimary: true,
                                    ),
                            );

                            final secondaryArticles = topic.articles
                                .where((a) => a.id != primaryArticle.id)
                                .take(3)
                                .toList();

                            return _buildGoogleNewsCard(
                              topic: topic,
                              primaryArticle: primaryArticle,
                              secondaryArticles: secondaryArticles,
                              isDark: isDark,
                              primaryColor: primaryColor,
                              cardBg: cardBg,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              borderColor: borderColor,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // Google News 卡片 (左主報導 + 右同主題報導 + 底部雙開按鈕)
  Widget _buildGoogleNewsCard({
    required InsuranceNewsTopic topic,
    required InsuranceNewsArticle primaryArticle,
    required List<InsuranceNewsArticle> secondaryArticles,
    required bool isDark,
    required Color primaryColor,
    required Color cardBg,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 話題 Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.stars_rounded, size: 16, color: primaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  topic.topicTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 主體：Google News 左右/上下佈局
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左側主頭條
                    Expanded(
                      flex: 5,
                      child: _buildPrimaryArticleItem(primaryArticle, topic.mainImageUrl, isDark, primaryColor, textColor, subTextColor),
                    ),

                    const SizedBox(width: 24),
                    Container(width: 1, height: 160, color: borderColor),
                    const SizedBox(width: 24),

                    // 右側同主題其他媒體新聞
                    Expanded(
                      flex: 6,
                      child: _buildSecondaryArticlesList(secondaryArticles, isDark, primaryColor, textColor, subTextColor),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPrimaryArticleItem(primaryArticle, topic.mainImageUrl, isDark, primaryColor, textColor, subTextColor),
                    const Divider(height: 24),
                    _buildSecondaryArticlesList(secondaryArticles, isDark, primaryColor, textColor, subTextColor),
                  ],
                ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // 底部：雙按鈕 (採用零延遲順滑陰影按鈕 _SmoothHoverButton)
          Row(
            children: [
              // 按鈕 1: 瀏覽相關媒體報導
              Expanded(
                child: _SmoothHoverButton(
                  onPressed: () => _showAllArticlesModal(topic, isDark, primaryColor),
                  icon: Icon(Icons.list_alt_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                  label: Text('瀏覽相關媒體報導 (${topic.articles.length})'),
                  backgroundColor: cardBg,
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  shadowColor: borderColor,
                  borderSide: BorderSide(color: borderColor),
                ),
              ),

              const SizedBox(width: 12),

              // 按鈕 2: 💡 AI 新聞重點摘要
              Expanded(
                child: _SmoothHoverButton(
                  onPressed: () => _showAiSummaryModal(topic, isDark, primaryColor),
                  icon: Icon(Icons.lightbulb_rounded, size: 18, color: primaryColor),
                  label: const Text('💡 AI 新聞重點摘要'),
                  backgroundColor: primaryColor.withOpacity(0.12),
                  foregroundColor: primaryColor,
                  shadowColor: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 左側主新聞元件
  Widget _buildPrimaryArticleItem(
    InsuranceNewsArticle article,
    String? imageUrl,
    bool isDark,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
  ) {
    return InkWell(
      onTap: () => _showSingleArticleModal(article, isDark, primaryColor),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.newspaper, size: 14, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                article.sourceName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            article.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '主要封面頭條 • 點擊觀看單篇摘要',
            style: TextStyle(fontSize: 12, color: subTextColor),
          ),
        ],
      ),
    );
  }

  // 右側同主題其他媒體元件
  Widget _buildSecondaryArticlesList(
    List<InsuranceNewsArticle> secondaryArticles,
    bool isDark,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
  ) {
    if (secondaryArticles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('目前無其他同主題次要媒體報導', style: TextStyle(color: subTextColor, fontSize: 13)),
      );
    }

    return Column(
      children: secondaryArticles.map((art) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showSingleArticleModal(art, isDark, primaryColor),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    art.sourceName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    art.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
