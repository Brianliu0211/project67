import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class CustomerRelationshipService {
  static const String tableName = 'customer_relationships';

  /// Fetch all customer relationships from Supabase (with offline fallback)
  static Future<List<Map<String, dynamic>>> fetchAllRelationships() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final data = await client
            .from(tableName)
            .select('*')
            .order('created_at', ascending: false);

        if (data != null) {
          final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(data);
          OfflineDataStore.customerRelationships = list;
          return list;
        }
      }
    } catch (e) {
      // Fallback to offline store
    }
    return OfflineDataStore.customerRelationships;
  }

  /// Add a new relationship between two customers
  static Future<bool> addRelationship({
    required String sourceCustomerId,
    required String targetCustomerId,
    required String relationshipType, // 'family', 'workplace', 'social', 'other'
    required String relationshipDetail,
  }) async {
    final Map<String, dynamic> newRecord = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'source_customer_id': sourceCustomerId,
      'target_customer_id': targetCustomerId,
      'relationship_type': relationshipType,
      'relationship_detail': relationshipDetail,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final inserted = await client.from(tableName).insert({
          'user_id': user.id,
          'source_customer_id': sourceCustomerId,
          'target_customer_id': targetCustomerId,
          'relationship_type': relationshipType,
          'relationship_detail': relationshipDetail,
        }).select().single();

        if (inserted != null) {
          OfflineDataStore.customerRelationships.insert(0, Map<String, dynamic>.from(inserted));
          return true;
        }
      }
    } catch (e) {
      // Offline fallback
    }

    OfflineDataStore.customerRelationships.insert(0, newRecord);
    return true;
  }

  /// Delete a relationship record
  static Future<bool> deleteRelationship(String id) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from(tableName).delete().eq('id', id);
      }
    } catch (e) {
      // Offline fallback
    }
    OfflineDataStore.customerRelationships.removeWhere((r) => r['id'].toString() == id);
    return true;
  }

  /// Update referral_source_id for a customer
  static Future<bool> updateReferralSource({
    required String customerId,
    required String? referralSourceId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('customers').update({
          'referral_source_id': referralSourceId,
        }).eq('id', customerId);
      }
    } catch (e) {
      // Offline fallback
    }

    // Update in local store
    final idx = OfflineDataStore.customers.indexWhere((c) => c['id'].toString() == customerId);
    if (idx != -1) {
      OfflineDataStore.customers[idx]['referral_source_id'] = referralSourceId;
    }
    return true;
  }
}
