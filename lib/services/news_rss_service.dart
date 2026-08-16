import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsRssSource {
  final String id;
  final String sourceName;
  final String rssUrl;
  final String category;
  final bool isActive;
  final String healthStatus;
  final DateTime? lastFetchedAt;

  NewsRssSource({
    required this.id,
    required this.sourceName,
    required this.rssUrl,
    required this.category,
    required this.isActive,
    required this.healthStatus,
    this.lastFetchedAt,
  });

  factory NewsRssSource.fromJson(Map<String, dynamic> json) {
    return NewsRssSource(
      id: json['id']?.toString() ?? '',
      sourceName: json['source_name'] ?? '未命名來源',
      rssUrl: json['rss_url'] ?? '',
      category: json['category'] ?? '保險財經',
      isActive: json['is_active'] ?? true,
      healthStatus: json['health_status'] ?? '200 OK',
      lastFetchedAt: json['last_fetched_at'] != null ? DateTime.tryParse(json['last_fetched_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source_name': sourceName,
      'rss_url': rssUrl,
      'category': category,
      'is_active': isActive,
      'health_status': healthStatus,
    };
  }
}

class NewsRssService {
  static final NewsRssService _instance = NewsRssService._internal();
  factory NewsRssService() => _instance;
  NewsRssService._internal();

  final _supabase = Supabase.instance.client;

  /// 取得所有已註冊的動態 RSS 來源
  Future<List<NewsRssSource>> getRssSources() async {
    try {
      final res = await _supabase
          .from('news_rss_sources')
          .select()
          .order('created_at', ascending: true);

      return (res as List).map((e) => NewsRssSource.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) print('Error loading RSS sources: $e');
      // Fallback default sources
      return [
        NewsRssSource(id: '1', sourceName: '中央社 - 產經金融', rssUrl: 'https://feeds.feedburner.com/cnaFirstNews', category: '權威通訊社', isActive: true, healthStatus: '200 OK'),
        NewsRssSource(id: '2', sourceName: '鉅亨網 - 保險理財', rssUrl: 'https://news.cnyes.com/rss/category/insurance', category: '財經專業', isActive: true, healthStatus: '200 OK'),
        NewsRssSource(id: '3', sourceName: '工商時報 - 金融保險', rssUrl: 'https://ctee.com.tw/feed', category: '產經大報', isActive: true, healthStatus: '200 OK'),
        NewsRssSource(id: '4', sourceName: '經濟日報 - 金融要聞', rssUrl: 'https://money.udn.com/rssfeed/news/1001/5591', category: '財經權威', isActive: true, healthStatus: '200 OK'),
        NewsRssSource(id: '5', sourceName: '數位時代 - 科技金融', rssUrl: 'https://www.bnext.com.tw/rss', category: '創新科技', isActive: true, healthStatus: '200 OK'),
        NewsRssSource(id: '6', sourceName: '保險事業發展中心 (TII)', rssUrl: 'https://www.tii.org.tw/open-data/rss/news.xml', category: '官方機構', isActive: true, healthStatus: '200 OK'),
        NewsRssSource(id: '7', sourceName: '金管會保險局 - 最新公告', rssUrl: 'https://www.ib.gov.tw/ch/rss/bulletin.xml', category: '監理主管', isActive: true, healthStatus: '200 OK'),
      ];
    }
  }

  /// 測試 RSS 網址連線是否有效 (Ping Test)
  Future<Map<String, dynamic>> testRssConnectivity(String url) async {
    final startTime = DateTime.now();
    try {
      final uri = Uri.parse(url);
      if (!uri.isAbsolute || (!uri.scheme.startsWith('http'))) {
        return {'success': false, 'message': '網址格式錯誤，必須以 http:// 或 https:// 開頭'};
      }

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      final latency = DateTime.now().difference(startTime).inMilliseconds;

      if (res.statusCode >= 200 && res.statusCode < 400) {
        final body = res.body.toLowerCase();
        final isXmlOrRss = body.contains('<rss') || body.contains('<feed') || body.contains('<?xml') || body.contains('<channel');
        return {
          'success': true,
          'httpCode': res.statusCode,
          'latencyMs': latency,
          'isValidRss': isXmlOrRss,
          'message': isXmlOrRss ? '連線成功！偵測到有效 RSS/XML 訂閱源 (${latency}ms)' : '連線成功，但內容非典型 RSS/XML 格式，請確認網址。',
        };
      } else {
        return {
          'success': false,
          'httpCode': res.statusCode,
          'latencyMs': latency,
          'message': 'HTTP ${res.statusCode} 伺服器回應異常',
        };
      }
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      return {
        'success': false,
        'httpCode': 0,
        'latencyMs': latency,
        'message': '連線超時或主機未回應 ($e)',
      };
    }
  }

  /// 手動新增 RSS 來源並持久化寫入 Supabase
  Future<bool> addRssSource({
    required String sourceName,
    required String rssUrl,
    required String category,
  }) async {
    try {
      await _supabase.from('news_rss_sources').insert({
        'source_name': sourceName.trim(),
        'rss_url': rssUrl.trim(),
        'category': category.trim().isEmpty ? '保險財經' : category.trim(),
        'is_active': true,
        'health_status': '200 OK',
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('Error adding RSS source: $e');
      return false;
    }
  }

  /// 切換 RSS 來源啟用狀態
  Future<bool> toggleSourceStatus(String id, bool isActive) async {
    try {
      await _supabase
          .from('news_rss_sources')
          .update({'is_active': isActive})
          .eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error toggling source status: $e');
      return false;
    }
  }

  /// 刪除自訂 RSS 來源
  Future<bool> deleteRssSource(String id) async {
    try {
      await _supabase.from('news_rss_sources').delete().eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting RSS source: $e');
      return false;
    }
  }
}
