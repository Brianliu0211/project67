import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../services/tag_categorizer.dart';

class VisitProjectsTab extends StatefulWidget {
  const VisitProjectsTab({super.key});

  @override
  State<VisitProjectsTab> createState() => _VisitProjectsTabState();
}

class _VisitProjectsTabState extends State<VisitProjectsTab> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  final Map<String, bool> _expandedProjects = {};

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  // Fetch visit projects from Supabase or SharedPreferences
  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedProjects = prefs.getString('offline_visit_projects');
        final storedProjCustomers = prefs.getString('offline_visit_project_customers');

        List<dynamic> localProjects = [];
        List<dynamic> localProjCustomers = [];

        if (storedProjects != null) {
          localProjects = jsonDecode(storedProjects);
        }
        if (storedProjCustomers != null) {
          localProjCustomers = jsonDecode(storedProjCustomers);
        }

        final List<Map<String, dynamic>> combined = [];
        for (var proj in localProjects) {
          final String projId = proj['id'];
          
          // Filter checklist customers for this project
          final List<dynamic> checklist = localProjCustomers
              .where((c) => c['visit_project_id'] == projId)
              .toList();

          combined.add({
            ...proj,
            'visit_project_customers': checklist,
          });
        }

        if (mounted) {
          setState(() {
            _projects = combined;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          _showToast('${context.l10n('pv_load_fail')}: $e', isError: true);
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    // Online Mode
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception(context.l10n('pv_user_not_logged_in'));

      final response = await supabase
          .from('visit_projects')
          .select('*, visit_project_customers(*, customers(*))')
          .eq('profile_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showToast('${context.l10n('pv_load_fail')}: $e', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Toggle checklist item is_visited status
  Future<void> _toggleVisit({
    required String projectId,
    required String relationId,
    required String customerId,
    required bool isVisitedValue,
  }) async {
    if (isOfflineMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // 1. Update checklist relation
        final storedProjCustomers = prefs.getString('offline_visit_project_customers');
        if (storedProjCustomers == null) return;

        final List<dynamic> localProjCustomers = jsonDecode(storedProjCustomers);
        final index = localProjCustomers.indexWhere((c) => c['id'] == relationId);
        if (index != -1) {
          localProjCustomers[index]['is_visited'] = isVisitedValue;
          await prefs.setString('offline_visit_project_customers', jsonEncode(localProjCustomers));
        }

        // 2. Check if all items in project are visited
        final projectChecklist = localProjCustomers
            .where((c) => c['visit_project_id'] == projectId)
            .toList();
        final bool isAllVisited = projectChecklist.isNotEmpty && 
            projectChecklist.every((c) => c['is_visited'] == true);

        // 3. Update project completion state
        final storedProjects = prefs.getString('offline_visit_projects');
        if (storedProjects != null) {
          final List<dynamic> localProjects = jsonDecode(storedProjects);
          final projIndex = localProjects.indexWhere((p) => p['id'] == projectId);
          if (projIndex != -1) {
            localProjects[projIndex]['is_completed'] = isAllVisited;
            await prefs.setString('offline_visit_projects', jsonEncode(localProjects));
          }
        }

        // Refresh UI state directly
        _fetchProjects();
        _showToast(isVisitedValue ? context.l10n('pv_visit_marked') : context.l10n('pv_visit_unmarked'));
      } catch (e) {
        _showToast('${context.l10n('pv_update_fail')}: $e', isError: true);
      }
      return;
    }

    // Online Mode
    try {
      final supabase = Supabase.instance.client;

      // 1. Update project customer record
      await supabase
          .from('visit_project_customers')
          .update({'is_visited': isVisitedValue})
          .eq('id', relationId);

      // 2. Fetch all checklist items of this project to check completion
      final checklistResponse = await supabase
          .from('visit_project_customers')
          .select('is_visited')
          .eq('visit_project_id', projectId);

      final List checklist = checklistResponse as List;
      final bool isAllVisited = checklist.isNotEmpty && 
          checklist.every((c) => c['is_visited'] == true);

      // 3. Update project completed status
      await supabase
          .from('visit_projects')
          .update({'is_completed': isAllVisited})
          .eq('id', projectId);

      _fetchProjects();
      _showToast(isVisitedValue ? context.l10n('pv_visit_marked') : context.l10n('pv_visit_unmarked'));
    } catch (e) {
      _showToast('${context.l10n('pv_update_fail')}: $e', isError: true);
    }
  }

  // Delete Visit Project
  Future<void> _deleteProject(String projectId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(context.l10n('pv_confirm_delete_title'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        content: Text(context.l10n('pv_confirm_delete_body'), style: TextStyle(color: textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n('pv_cancel'), style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n('pv_delete')),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    if (isOfflineMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Remove project
        final storedProjects = prefs.getString('offline_visit_projects');
        if (storedProjects != null) {
          final List<dynamic> localProjects = jsonDecode(storedProjects);
          localProjects.removeWhere((p) => p['id'] == projectId);
          await prefs.setString('offline_visit_projects', jsonEncode(localProjects));
        }

        // Remove project customer relations
        final storedProjCustomers = prefs.getString('offline_visit_project_customers');
        if (storedProjCustomers != null) {
          final List<dynamic> localProjCustomers = jsonDecode(storedProjCustomers);
          localProjCustomers.removeWhere((c) => c['visit_project_id'] == projectId);
          await prefs.setString('offline_visit_project_customers', jsonEncode(localProjCustomers));
        }

        _fetchProjects();
        _showToast(context.l10n('pv_delete_success'));
      } catch (e) {
        _showToast('${context.l10n('pv_delete_fail')}: $e', isError: true);
      }
      return;
    }

    // Online Mode
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('visit_projects').delete().eq('id', projectId);
      _fetchProjects();
      _showToast(context.l10n('pv_delete_success'));
    } catch (e) {
      _showToast('${context.l10n('pv_delete_fail')}: $e', isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.redAccent : AppSettings.instance.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Description
            Text(
              context.l10n('pv_description'),
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Project List Area
            Expanded(
              child: _isLoading
                  ? _buildShimmerLoader()
                  : _projects.isEmpty
                      ? _buildEmptyState(isDark, primaryColor)
                      : ListView.builder(
                          itemCount: _projects.length,
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            final String projId = project['id'];
                            final List checklist = project['visit_project_customers'] ?? [];
                            final bool isExpanded = _expandedProjects[projId] ?? false;

                            // Calculate progress
                            final int total = checklist.length;
                            final int visited = checklist.where((c) => c['is_visited'] == true).length;
                            final double progress = total > 0 ? visited / total : 0.0;
                            final bool isCompleted = project['is_completed'] ?? false;

                            return _buildProjectCard(
                              project: project,
                              checklist: checklist,
                              total: total,
                              visited: visited,
                              progress: progress,
                              isCompleted: isCompleted,
                              isExpanded: isExpanded,
                              isDark: isDark,
                              primaryColor: primaryColor,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Project Card Widget
  Widget _buildProjectCard({
    required Map<String, dynamic> project,
    required List checklist,
    required int total,
    required int visited,
    required double progress,
    required bool isCompleted,
    required bool isExpanded,
    required bool isDark,
    required Color primaryColor,
  }) {
    final String projId = project['id'];
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade200;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Project Summary Panel
          InkWell(
            onTap: () {
              setState(() {
                _expandedProjects[projId] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Customer Count Badge
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${context.l10n('pv_list_count')}: $total',
                          style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      
                      // Project Title
                      Expanded(
                        child: Text(
                          project['title'] ?? '',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // Delete Action
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteProject(projId),
                        tooltip: context.l10n('pv_delete_tooltip'),
                      ),
                      
                      // Expand Icon
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: subTextColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Project Purpose (Why)
                  Text(
                    '${context.l10n('pv_purpose')}：${project['purpose'] ?? ''}',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Checklist Details (Expanded View)
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              color: isDark ? const Color(0xFF0D1117).withOpacity(0.5) : Colors.grey.shade50,
              padding: const EdgeInsets.all(16),
              child: total == 0
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          context.l10n('pv_no_customers'),
                          style: TextStyle(color: subTextColor, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: checklist.length,
                      itemBuilder: (context, idx) {
                        final item = checklist[idx];
                        
                        // Extract customer object from online 'customers' or offline 'customer'
                        final customer = item['customers'] ?? item['customer'];
                        if (customer == null) return const SizedBox.shrink();

                        final String custName = customer['name'] ?? '';
                        final String custNickname = customer['nickname'] ?? '';
                        final String dispName = custNickname.isNotEmpty ? '$custName ($custNickname)' : custName;
                        final String avatarUrl = customer['avatar_url'] ?? '';
                        final String nameInitial = custName.isNotEmpty ? custName.substring(0, 1) : '?';
                        final String phone = customer['phone'] ?? '';
                        final String remark = customer['remark'] ?? '';

                        List<dynamic> tagsList = [];
                        if (customer['tags'] is List) {
                          tagsList = customer['tags'];
                        } else if (customer['tags'] is String) {
                          try {
                            tagsList = jsonDecode(customer['tags']);
                          } catch (_) {}
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          margin: EdgeInsets.only(bottom: idx == checklist.length - 1 ? 0 : 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F242C) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: borderColor.withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Small Avatar
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: primaryColor.withOpacity(0.12),
                                    backgroundImage: _getAvatarProvider(avatarUrl),
                                    child: avatarUrl.isEmpty
                                        ? Text(
                                            nameInitial,
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Customer name clickable
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showZoomDetails(context, customer),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          dispName,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                            decorationStyle: TextDecorationStyle.dashed,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Phone display
                                  if (phone.isNotEmpty) ...[
                                    Icon(Icons.phone_outlined, color: subTextColor, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              
                              // Tag Chips
                              if (tagsList.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: tagsList.map<Widget>((tag) {
                                    final style = TagCategorizer.getStyle(tag.toString(), isDark);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: style.backgroundColor,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: style.textColor.withOpacity(0.3), width: 0.5),
                                      ),
                                      child: Text(
                                        tag.toString(),
                                        style: TextStyle(
                                          color: style.textColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              
                              // Remark / Notes
                              if (remark.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF161B22) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF30363D) : Colors.grey.shade200,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.notes, color: subTextColor.withOpacity(0.7), size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          remark,
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // Detail Modal for Customer Preview
  void _showZoomDetails(BuildContext context, Map<String, dynamic> customer) {
    final String name = customer['name'] ?? '';
    final String nickname = customer['nickname'] ?? '';
    final String phone = customer['phone'] ?? '--';
    final String email = customer['email'] ?? '--';
    final String notes = customer['notes'] ?? '';
    final String avatarUrl = customer['avatar_url'] ?? '';
    final List tags = customer['tags'] is List ? customer['tags'] : [];

    final String displayName = nickname.isNotEmpty ? '$name ($nickname)' : name;
    final String nameInitial = name.isNotEmpty ? name.substring(0, 1) : '?';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: primaryColor.withOpacity(0.12),
                        backgroundImage: _getAvatarProvider(avatarUrl),
                        child: avatarUrl.isEmpty
                            ? Text(
                                nameInitial,
                                style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n('pv_customer_info'),
                              style: TextStyle(color: subTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Phone and Email
                  Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded, color: primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Text(phone, style: TextStyle(color: textColor, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.mail_outline_rounded, color: primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Text(email, style: TextStyle(color: textColor, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tags
                  Text(
                    context.l10n('pv_tags'),
                    style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) {
                        final style = TagCategorizer.getStyle(tag.toString(), isDark);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: style.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag.toString(),
                            style: TextStyle(
                              color: style.textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Text(context.l10n('pv_no_tags'), style: TextStyle(color: subTextColor, fontSize: 12)),
                  const SizedBox(height: 20),

                  // Notes
                  Text(
                    context.l10n('pv_notes'),
                    style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notes.isNotEmpty ? notes : context.l10n('pv_no_notes'),
                    style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Shimmer Loader Component
  Widget _buildShimmerLoader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color baseColor = isDark ? const Color(0xFF161B22) : Colors.grey.shade200;

    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 150, height: 16, color: isDark ? Colors.white10 : Colors.white),
              const SizedBox(height: 12),
              Container(width: 300, height: 12, color: isDark ? Colors.white10 : Colors.white),
              const Spacer(),
              Container(width: double.infinity, height: 8, color: isDark ? Colors.white10 : Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState(bool isDark, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 64,
            color: primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n('pv_empty_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n('pv_empty_body'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to parse Base64 or Network URL image provider
  ImageProvider? _getAvatarProvider(String avatarUrl) {
    if (avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('data:image/') || avatarUrl.startsWith('data:application/')) {
      try {
        final base64String = avatarUrl.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(avatarUrl);
  }
}
