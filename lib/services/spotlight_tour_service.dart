import 'package:flutter/material.dart';

/// 導覽章節模型
class TourChapter {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<TourStep> steps;

  const TourChapter({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
  });
}

/// 單步導覽步驟模型
class TourStep {
  final String stepId;
  final String title;
  final String content;
  final GlobalKey? targetKey;
  final Alignment tooltipAlignment;

  const TourStep({
    required this.stepId,
    required this.title,
    required this.content,
    this.targetKey,
    this.tooltipAlignment = Alignment.bottomCenter,
  });
}

/// 全站 Spotlight 章節式新手導覽服務 (SpotlightTourService)
class SpotlightTourService extends ChangeNotifier {
  static final SpotlightTourService instance = SpotlightTourService._internal();
  SpotlightTourService._internal();

  bool _isTourActive = false;
  int _currentChapterIndex = 0;
  int _currentStepIndex = 0;

  bool get isTourActive => _isTourActive;
  int get currentChapterIndex => _currentChapterIndex;
  int get currentStepIndex => _currentStepIndex;

  /// 全站四大章節導覽定義
  final List<TourChapter> chapters = const [
    TourChapter(
      id: 'quick_start',
      title: '章節一：極速上手',
      description: '學習如何使用語音助理、查看今日行程與客戶清單。',
      icon: Icons.flash_on_rounded,
      steps: [
        TourStep(
          stepId: 'welcome',
          title: '🌟 歡迎使用 insurance_helper',
          content: '專為保險經紀人與業務員打造的 CRM 戰情中樞！讓我們用 30 秒快速了解系統精髓。',
        ),
        TourStep(
          stepId: 'voice_scheduler',
          title: '🎙️ 語音排程與筆記助手',
          content: '按下底部霓虹麥克風，用「說」的就能自動新增行程與記錄客戶拜訪心得！',
        ),
        TourStep(
          stepId: 'today_schedule',
          title: '📅 今日行程與時間軸',
          content: '支援「日時間軸」與「月網格」雙視圖，行程重疊時自動並排，並可一鍵跳轉多站導航。',
        ),
      ],
    ),
    TourChapter(
      id: 'customers_safecheck',
      title: '章節二：客戶管理與 SafeCheck 健診',
      description: '3D 翻轉名片、條款對照卡與 X vs Y 商品白話 PK。',
      icon: Icons.style_rounded,
      steps: [
        TourStep(
          stepId: 'customer_card',
          title: '💳 3D 翻轉客戶卡片',
          content: '點擊客戶卡片可 3D 翻轉查看備註與綽號，點擊雙向按鈕可開啟詳情彈窗。',
        ),
        TourStep(
          stepId: 'safecheck_healthcheck',
          title: '🛡️ SafeCheck 白話條款健診',
          content: '內嵌 1.1 萬+ 保險商品庫，自動解析保證續保、等待期天數與除外責任白話摘要！',
        ),
        TourStep(
          stepId: 'policy_pk',
          title: '⚔️ X vs Y 商品白話 PK 卡',
          content: '提供兩兩商品白話對比圖卡，一鍵轉發發給客戶，面談溝通秒懂痛點。',
        ),
      ],
    ),
    TourChapter(
      id: 'route_news',
      title: '章節三：路線規劃與產業情報',
      description: '多站導航一鍵外包與每日保險頭條新聞。',
      icon: Icons.map_rounded,
      steps: [
        TourStep(
          stepId: 'google_maps_route',
          title: '🗺️ Google Maps 多站順路導航',
          content: '勾選今日拜訪地點，一鍵外包給 Google Maps 原生 App 自動規劃最佳避塞車順路路線！',
        ),
        TourStep(
          stepId: 'daily_news',
          title: '📰 保險今日頭條',
          content: '每日自動抓取 7 大權威媒體最新條款與法規動態，AI 自動生成單段重點摘要。',
        ),
      ],
    ),
    TourChapter(
      id: 'profile_settings',
      title: '章節四：個人名片與系統設定',
      description: '真實正式商務名片與設定頁導覽控制器。',
      icon: Icons.badge_rounded,
      steps: [
        TourStep(
          stepId: 'formal_business_card',
          title: '💼 正式質感業務員名片',
          content: '比照實體金邊商務名片打造！含保險公司 Logo、登錄字號、專業證照與聯絡 QR Code。',
        ),
        TourStep(
          stepId: 'settings_replay',
          title: '🎓 導覽重播控制器',
          content: '隨時可在「系統設定」頁面重新播放完整導覽，或按章節獨立選看複習！',
        ),
      ],
    ),
  ];

  TourChapter get currentChapter => chapters[_currentChapterIndex];
  TourStep get currentStep => currentChapter.steps[_currentStepIndex];

  /// 啟動指定章節或從頭啟動
  void startTour({int chapterIndex = 0}) {
    _currentChapterIndex = chapterIndex.clamp(0, chapters.length - 1);
    _currentStepIndex = 0;
    _isTourActive = true;
    notifyListeners();
  }

  /// 下一步
  void nextStep() {
    if (_currentStepIndex < currentChapter.steps.length - 1) {
      _currentStepIndex++;
    } else if (_currentChapterIndex < chapters.length - 1) {
      _currentChapterIndex++;
      _currentStepIndex = 0;
    } else {
      endTour();
      return;
    }
    notifyListeners();
  }

  /// 上一步
  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
    } else if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      _currentStepIndex = chapters[_currentChapterIndex].steps.length - 1;
    }
    notifyListeners();
  }

  /// 結束/關閉導覽
  void endTour() {
    _isTourActive = false;
    notifyListeners();
  }
}
