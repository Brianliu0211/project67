import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

class PlaceSearchResult {
  final String displayName;
  final double latitude;
  final double longitude;

  PlaceSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final rawName = json['display_name'] as String? ?? '';
    final formattedName = LocationService.formatTaiwanAddress(rawName);
    return PlaceSearchResult(
      displayName: formattedName.isNotEmpty ? formattedName : rawName,
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
    );
  }
}

class LocationService {
  LocationService._();

  /// 格式化台灣地址（將 OpenStreetMap 倒序逗號分隔字串轉換為順序中文地址）
  static String formatTaiwanAddress(String rawAddress) {
    if (rawAddress.trim().isEmpty) return '';
    final parts = rawAddress.split(',').map((e) => e.trim()).toList();
    if (parts.length <= 1) return rawAddress;

    // 移除國名與純數字郵遞區號
    final filtered = parts.where((p) {
      if (p == '台灣' || p == '臺灣' || p.toLowerCase() == 'taiwan') return false;
      if (RegExp(r'^\d{3,6}$').hasMatch(p)) return false; // 郵遞區號
      return true;
    }).toList();

    if (filtered.isEmpty) return rawAddress;

    // Nominatim 格式通常為 [門牌/標的, 巷弄, 路街, 區, 縣市]
    // 逆向拼接即可得到符合台灣習慣的地址 (縣市 -> 區 -> 路 -> 門牌)
    return filtered.reversed.join('');
  }

  /// 取得使用者當前概略定位（免 API 金鑰 IP 定位）
  static Future<Map<String, double>?> getCurrentUserLocation() async {
    try {
      final response = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }
    } catch (e) {
      // 預設台北 101
    }
    return {'latitude': 25.0330, 'longitude': 121.5654};
  }

  /// 搜尋地點（利用 OpenStreetMap Nominatim API，限定台灣 `countrycodes=tw`，防地點亂跑）
  static Future<List<PlaceSearchResult>> searchPlaces(String query, {double? userLat, double? userLng}) async {
    if (query.trim().isEmpty) return [];

    try {
      String url = 'https://nominatim.openstreetmap.org/search?'
          'format=json&q=${Uri.encodeComponent(query)}&accept-language=zh-TW,zh,en&countrycodes=tw&limit=6';

      if (userLat != null && userLng != null) {
        final minLon = userLng - 0.5;
        final minLat = userLat - 0.5;
        final maxLon = userLng + 0.5;
        final maxLat = userLat + 0.5;
        url += '&viewbox=$minLon,$maxLat,$maxLon,$minLat';
      }

      final uri = Uri.parse(url);

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'InsuranceHelperApp/1.0 (contact@insurancehelper.local)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((item) => PlaceSearchResult.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      // 網路異常或逾時時防護
    }
    return [];
  }

  /// 取得點位之間的真實道路導航路線 (利用免費 OSRM Driving Route Engine)
  static Future<List<LatLng>> getRouteGeometry(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;

    try {
      final coordsStr = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordsStr?overview=full&geometries=geojson',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'InsuranceHelperApp/1.0 (contact@insurancehelper.local)',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes.first as Map<String, dynamic>;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          if (geometry != null) {
            final coordinates = geometry['coordinates'] as List<dynamic>?;
            if (coordinates != null) {
              return coordinates.map((pt) {
                final pair = pt as List<dynamic>;
                final lon = (pair[0] as num).toDouble();
                final lat = (pair[1] as num).toDouble();
                return LatLng(lat, lon);
              }).toList();
            }
          }
        }
      }
    } catch (e) {
      // 逾時時降級傳回原點位
    }
    return waypoints;
  }

  /// 經緯度逆向轉為完整台灣中文地址
  static Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&lat=$lat&lon=$lon&accept-language=zh-TW,zh,en',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'InsuranceHelperApp/1.0 (contact@insurancehelper.local)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawName = data['display_name'] as String?;
        if (rawName != null) {
          final formatted = formatTaiwanAddress(rawName);
          return formatted.isNotEmpty ? formatted : rawName;
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 開啟外部 Google Maps 免費導覽/地點查看
  static Future<void> openInGoogleMaps({double? lat, double? lon, String? address}) async {
    String url;
    if (lat != null && lon != null) {
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    } else if (address != null && address.trim().isNotEmpty) {
      url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    } else {
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
