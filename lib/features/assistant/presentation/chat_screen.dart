import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../tasks/presentation/task_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _proposalConfirmed = false;
  bool _showErrorSimulation = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': true,
      'sender': 'أحمد',
      'time': '١٠:١٥ ص',
      'text': 'عندي حاجات كتير ومش عارف أبدأ منين.',
    },
    {
      'isUser': false,
      'sender': 'هندلها',
      'time': '١٠:١٦ ص',
      'headline': 'نبدأ بخطوة صغيرة؟',
      'text': 'مش لازم تخلص كل حاجة دلوقتي. أقترح نراجع تدفق المهام ٢٥ دقيقة، وبعدها تاخد راحة.',
      'hasProposal': true,
      'proposalTitle': 'مراجعة تدفق المهام وتجربة المستخدم',
      'proposalSub': 'إطلاق نسخة هندلها • اليوم، ١٢:٠٠ م',
      'tags': ['أولوية عالية', 'طاقة متوسطة', '٢٥ دقيقة'],
    },
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({
        'isUser': true,
        'sender': 'أحمد',
        'time': '١٠:١٨ ص',
        'text': text,
      });
      _msgCtrl.clear();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'isUser': false,
          'sender': 'هندلها',
          'time': '١٠:١٨ ص',
          'headline': 'خطوة في مكانها',
          'text': 'سجلت فكرتك وبجهزلك خطة بسيطة على قد طاقتك.',
          'hasProposal': false,
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final surface2 = isDark ? AppColors.darkSurface2 : const Color(0xFFF3F7F5);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final userBubbleBg = isDark ? const Color(0xFF1D3B35) : const Color(0xFFD6EDE7);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.more_horiz_rounded, color: textSecColor),
                    onPressed: () {
                      setState(() => _showErrorSimulation = !_showErrorSimulation);
                    },
                  ),
                  Column(
                    children: [
                      Text(
                        'مساعد هندلها',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'معاك، خطوة بخطوة',
                            style: TextStyle(fontSize: 12, color: textSecColor),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: textSecColor, size: 26),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                children: [
                  // Date separator
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'النهارده، ١٠:١٥ ص',
                        style: TextStyle(fontSize: 11.5, color: textMutedColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  for (final msg in _messages) ...[
                    if (msg['isUser'] == true) ...[
                      // User Bubble (Right)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: userBubbleBg,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg['text'] as String,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${msg['sender']} • ${msg['time']}',
                                style: TextStyle(fontSize: 11, color: textSecColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Assistant Message (Left)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.darkSecondary),
                              const SizedBox(width: 6),
                              Text(
                                msg['sender'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textSecColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (msg['headline'] != null) ...[
                            Text(
                              msg['headline'] as String,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],

                          Text(
                            msg['text'] as String,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Proposal Card
                          if (msg['hasProposal'] == true) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 14, color: textSecColor),
                                          const SizedBox(width: 4),
                                          Text('تعديل', style: TextStyle(fontSize: 11.5, color: textSecColor)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.assistantPurpleSoft : const Color(0xFFECEAF4),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'اقتراح • مستني تأكيدك',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.darkSecondary : const Color(0xFF675C8E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    msg['proposalTitle'] as String,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['proposalSub'] as String,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 12, color: textSecColor),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _buildTagChip('٢٥ دقيقة', surface2, textSecColor),
                                      const SizedBox(width: 6),
                                      _buildTagChip('طاقة متوسطة', surface2, textSecColor),
                                      const SizedBox(width: 6),
                                      _buildTagChip('أولوية عالية', isDark ? const Color(0xFF4A2B28) : const Color(0xFFFDE8E6), isDark ? AppColors.salmonBadge : const Color(0xFFD6453D)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  ElevatedButton(
                                    onPressed: _proposalConfirmed
                                        ? null
                                        : () {
                                            ref.read(todayTasksProvider.notifier).createTask(title: msg['proposalTitle'] as String);
                                            setState(() => _proposalConfirmed = true);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _proposalConfirmed ? const Color(0xFF28564E) : primaryColor,
                                      foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                                      minimumSize: const Size(double.infinity, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(
                                      _proposalConfirmed ? 'تم تأكيد التحديث ✓' : 'تأكيد تحديث المهمة الحالية ✓',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppColors.darkBackground : Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Center(
                                    child: Text(
                                      'لسه ما اتغيّرش حاجة • مش هنضيف مهمة مكررة',
                                      style: TextStyle(fontSize: 11, color: textMutedColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Connection Failure / Retry Banner (Page 28)
                  if (_showErrorSimulation) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A2B28),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.salmonBadge),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.error_outline_rounded, color: AppColors.salmonBadge, size: 20),
                              SizedBox(width: 8),
                              Text('الرد ما وصلش', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'رسالتك لسه موجودة هنا. جرّب تاني لما الاتصال يتحسن.',
                            style: TextStyle(fontSize: 12.5, color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => setState(() => _showErrorSimulation = false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('إعادة إرسال الطلب ↻', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkBackground : Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),

            // Quick Suggestion Chips (Above Input)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildQuickChip('طاقتي قليلة', () {
                    _msgCtrl.text = 'طاقتي قليلة النهارده، محتاج خطوة خفيفة';
                  }, isDark, surfaceColor, borderColor, textColor),
                  const SizedBox(width: 8),
                  _buildQuickChip('رتّب معايا اليوم', () {
                    _msgCtrl.text = 'رتّب معايا أولويات اليوم';
                  }, isDark, surfaceColor, borderColor, textColor),
                  const SizedBox(width: 8),
                  _buildQuickChip('... بفكر في اقتراحات تانية', () {}, isDark, surfaceColor, borderColor, textColor),
                  const SizedBox(width: 8),
                  _buildQuickChip('إلغاء', () {}, isDark, surfaceColor, borderColor, textMutedColor),
                ],
              ),
            ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider)),
              ),
              child: Row(
                children: [
                  // Send button (Circle with up arrow)
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: isDark ? AppColors.darkBackground : Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Input text field
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: '...قولّي اللي في بالك',
                        hintStyle: TextStyle(color: textMutedColor, fontSize: 13.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ],
              ),
            ),

            // Footer note
            Container(
              padding: const EdgeInsets.only(bottom: 6, top: 4),
              color: surfaceColor,
              child: Center(
                child: Text(
                  'إنت صاحب القرار. راجع أي اقتراح قبل تأكيده.',
                  style: TextStyle(fontSize: 11, color: textMutedColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, bool isDark, Color surfaceColor, Color borderColor, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }
}
