import 'package:flutter/material.dart';
import '../services/spotlight_tour_service.dart';
import 'hover_animated_button.dart';

/// Spotlight 新手導覽全螢幕 Overlay 組件
class SpotlightTourOverlay extends StatelessWidget {
  const SpotlightTourOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final tourService = SpotlightTourService.instance;

    return AnimatedBuilder(
      animation: tourService,
      builder: (context, _) {
        if (!tourService.isTourActive) return const SizedBox.shrink();

        final chapter = tourService.currentChapter;
        final step = tourService.currentStep;
        final theme = Theme.of(context);

        return Stack(
          children: [
            // 半透明暗色背景
            GestureDetector(
              onTap: () {}, // 阻止傳遞
              child: Container(
                color: Colors.black.withOpacity(0.78),
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // 中央引導卡片 (Center Floating Tooltip Card)
            Center(
              child: Container(
                width: 460,
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.dialogBackgroundColor.withOpacity(0.98),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      blurRadius: 30.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 章節 Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            chapter.icon,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chapter.title,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                chapter.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: tourService.endTour,
                          tooltip: '跳過導覽',
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    // 步驟標題與說明
                    Text(
                      step.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 底部控制列 (進度指示器 + 按鈕)
                    Row(
                      children: [
                        // 章節與步驟進度點
                        Text(
                          '${tourService.currentChapterIndex + 1}/${tourService.chapters.length} 章節 (${tourService.currentStepIndex + 1}/${chapter.steps.length})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),

                        // 上一步按鈕
                        if (tourService.currentStepIndex > 0 || tourService.currentChapterIndex > 0) ...[
                          TextButton(
                            onPressed: tourService.previousStep,
                            child: const Text('上一步'),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // 下一步 / 完成按鈕
                        HoverAnimatedButton(
                          onPressed: tourService.nextStep,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          child: Text(
                            (tourService.currentChapterIndex == tourService.chapters.length - 1 &&
                                    tourService.currentStepIndex == chapter.steps.length - 1)
                                ? '🎉 完成導覽'
                                : '下一步',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
