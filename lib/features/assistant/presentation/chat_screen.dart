import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/handelha_brand.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_providers.dart';

enum MessageType { text, voiceNote, proposal, clarification }

class ChatMessageItem {
  final String id;
  final String text;
  final bool isFromUser;
  final DateTime time;
  final MessageType type;
  final String? audioDuration;
  final String? proposalTitle;
  final String? proposalDuration;
  final TaskPriority? proposalPriority;
  bool isConfirmed;

  ChatMessageItem({
    required this.id,
    required this.text,
    required this.isFromUser,
    required this.time,
    this.type = MessageType.text,
    this.audioDuration,
    this.proposalTitle,
    this.proposalDuration,
    this.proposalPriority,
    this.isConfirmed = false,
  });
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  bool _isRecording = false;
  late AnimationController _pulseController;

  final List<ChatMessageItem> _messages = [
    ChatMessageItem(
      id: '1',
      text: 'صباح الخير\nقول أو اكتب اللي في دماغك بكل حرية، ورتّبها لك خطوة خطوة بدون أي ضغط.',
      isFromUser: false,
      time: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    ChatMessageItem(
      id: '2',
      text: 'عندي اجتماع بكره الساعة 10 الصبح ولازم أراجع العرض التقديمي قبلها.',
      isFromUser: true,
      time: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    ChatMessageItem(
      id: '3',
      text: 'تمام، رتبتها لك على قد وقتك المتاح. دي الخطة المقترحة:',
      isFromUser: false,
      time: DateTime.now().subtract(const Duration(minutes: 2)),
      type: MessageType.proposal,
      proposalTitle: 'مراجعة العرض التقديمي',
      proposalDuration: '45 دقيقة',
      proposalPriority: TaskPriority.high,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendText() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessageItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isFromUser: true,
          time: DateTime.now(),
        ),
      );
      _messageCtrl.clear();
      _isSending = true;
    });

    _scrollToBottom();

    // محاكاة فهم المساعد وتوليد Proposal منظم بدون لوم أو توتر
    Future.delayed(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(
          ChatMessageItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: 'فهمت منك: «$text».\nتحب نثبتها كخطوة قابلة للتنفيذ؟',
            isFromUser: false,
            time: DateTime.now(),
            type: MessageType.proposal,
            proposalTitle: text,
            proposalDuration: '30 دقيقة',
            proposalPriority: TaskPriority.medium,
          ),
        );
      });
      _scrollToBottom();
    });
  }

  void _toggleMockVoiceRecord() {
    if (_isRecording) {
      // إنهاء التسجيل وإرسال صوتي
      setState(() {
        _isRecording = false;
        _messages.add(
          ChatMessageItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: 'رسالة صوتية',
            isFromUser: true,
            time: DateTime.now(),
            type: MessageType.voiceNote,
            audioDuration: '0:14',
          ),
        );
        _isSending = true;
      });
      _scrollToBottom();

      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _messages.add(
            ChatMessageItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: 'سمعت تسجيلك الصوتي: «عايز أشتري مستلزمات المكتب وأكلم المهندس أحمد».\nقسمتها لك لمهمتين:',
              isFromUser: false,
              time: DateTime.now(),
              type: MessageType.proposal,
              proposalTitle: 'شراء مستلزمات المكتب ومكالمة المهندس أحمد',
              proposalDuration: '25 دقيقة',
              proposalPriority: TaskPriority.medium,
            ),
          );
        });
        _scrollToBottom();
      });
    } else {
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _confirmProposal(ChatMessageItem item) async {
    setState(() {
      item.isConfirmed = true;
    });

    // إضافة المهمة محلياً لليوم
    if (item.proposalTitle != null) {
      await ref
          .read(todayTasksProvider.notifier)
            .createTask(
              title: item.proposalTitle!,
              priority: item.proposalPriority ?? TaskPriority.medium,
              estimatedDurationMinutes: 30,
              status: TaskStatus.planned,
              scheduledStartAt: DateTime.now(),
            );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت الإضافة لأولويات اليوم: «${item.proposalTitle}»',
        ),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const HandelhaLogo(markSize: 26, fontSize: 16),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: IconButton(
              tooltip: 'محادثة جديدة',
              onPressed: () {},
              icon: const Icon(Icons.edit_square, color: AppColors.primaryStrong, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // قائمة الرسائل
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isSending && index == _messages.length) {
                  return const _AssistantThinkingBubble();
                }
                final msg = _messages[index];
                return _ChatBubble(
                  message: msg,
                  onConfirmProposal: () => _confirmProposal(msg),
                );
              },
            ),
          ),

          // شريط التسجيل الصوتي المباشر (عند التفعيل)
          if (_isRecording)
            _RecordingBar(
              pulseAnimation: _pulseController,
              onStop: _toggleMockVoiceRecord,
              onCancel: () => setState(() => _isRecording = false),
            )
          else
            _ChatInputArea(
              controller: _messageCtrl,
              onSend: _handleSendText,
              onMicTap: _toggleMockVoiceRecord,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// فقاعة الشات (Chat Bubble)
// ---------------------------------------------------------------------------
class _ChatBubble extends StatelessWidget {
  final ChatMessageItem message;
  final VoidCallback onConfirmProposal;

  const _ChatBubble({required this.message, required this.onConfirmProposal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isFromUser;
    final isDark = theme.brightness == Brightness.dark;
    final userBubbleBg = isDark
        ? AppColors.darkPrimarySoft.withValues(alpha: 0.6)
        : AppColors.primarySoft;
    final assistantBubbleBg =
        isDark ? AppColors.darkSurface : AppColors.surface;
    final bubbleBorder = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkPrimarySoft
                        : AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: HandelhaMark(size: 22, dark: isDark)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? userBubbleBg : assistantBubbleBg,
                    borderRadius: BorderRadius.only(
                      topRight: const Radius.circular(16),
                      topLeft: const Radius.circular(16),
                      bottomRight: isUser
                          ? const Radius.circular(3)
                          : const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(3),
                    ),
                    border: Border.all(
                      color: isUser
                          ? (isDark
                              ? AppColors.darkPrimary.withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.2))
                          : bubbleBorder,
                      width: 1,
                    ),
                  ),
                  child: message.type == MessageType.voiceNote
                      ? _VoiceNotePlayer(
                          duration: message.audioDuration ?? '0:15',
                        )
                      : Text(
                          message.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: textColor,
                            height: 1.5,
                          ),
                        ),
                ),
              ),
              if (isUser) const SizedBox(width: 4),
            ],
          ),

          // Proposal Card
          if (message.type == MessageType.proposal &&
              message.proposalTitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 36),
              child: _ProposalCard(
                message: message,
                onConfirm: onConfirmProposal,
              ),
            ),
          ],

          // وقت الرسالة
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: isUser ? 0 : 36,
              end: isUser ? 8 : 0,
              top: 4,
            ),
            child: Text(
              _formatTime(message.time),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour < 12 ? 'ص' : 'م';
    return '$h:$m $p';
  }
}

// ---------------------------------------------------------------------------
// بطاقة الاقتراح المنظم (Proposal Card: #E7F0EA)
// ---------------------------------------------------------------------------
class _ProposalCard extends StatelessWidget {
  final ChatMessageItem message;
  final VoidCallback onConfirm;

  const _ProposalCard({required this.message, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDone = message.isConfirmed;
    final cardBg = isDark
        ? AppColors.darkSurface2
        : const Color(0xFFE7F0EA);
    final borderColor = isDark
        ? AppColors.darkPrimary.withValues(alpha: 0.35)
        : AppColors.primary.withValues(alpha: 0.35);
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 16,
                color: primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'اقتراح خطوة تنفيذية',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (message.proposalDuration != null)
                Text(
                  '⏱ ${message.proposalDuration}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.proposalTitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (isDone)
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: isDark ? AppColors.darkSuccess : AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'تم اعتماد الخطوة وإضافتها لليوم',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkPrimary : AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('تأكيد وإضافة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primaryDark,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('تعديل', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عارض التسجيل الصوتي داخل الشات
// ---------------------------------------------------------------------------
class _VoiceNotePlayer extends StatelessWidget {
  final String duration;
  const _VoiceNotePlayer({required this.duration});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPrimary : AppColors.primaryDark,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: isDark ? AppColors.darkBackground : Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        // Mock Waveform
        Row(
          children: List.generate(14, (i) {
            final heights = [
              8.0,
              14.0,
              20.0,
              10.0,
              18.0,
              24.0,
              16.0,
              12.0,
              22.0,
              18.0,
              14.0,
              8.0,
              12.0,
              6.0,
            ];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: heights[i % heights.length],
              decoration: BoxDecoration(
                color: i < 6 ? AppColors.primaryDark : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(width: 10),
        Text(
          duration,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// مؤشر التفكير الهادئ للمساعد
// ---------------------------------------------------------------------------
class _AssistantThinkingBubble extends StatelessWidget {
  const _AssistantThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: AppColors.primaryDark,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'جاري ترتيب أفكارك...',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// شريط الإدخال المعتاد
// ---------------------------------------------------------------------------
class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  const _ChatInputArea({
    required this.controller,
    required this.onSend,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final inputBg = isDark ? AppColors.darkSurface2 : AppColors.surfaceSoft;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primaryStrong;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      color: bgColor,
      child: Container(
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.mic_none_rounded, color: primaryColor),
              tooltip: 'تسجيل صوتي',
              onPressed: onMicTap,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'اكتب هنا...',
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_upward_rounded, color: isDark ? AppColors.darkBackground : Colors.white, size: 20),
                tooltip: 'إرسال',
                onPressed: onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// شريط التسجيل الصوتي الحي مع نبض هادئ (Pulse)
// ---------------------------------------------------------------------------
class _RecordingBar extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _RecordingBar({
    required this.pulseAnimation,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (pulseAnimation.value * 0.15),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.primaryDark,
                    size: 22,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'بيسجل صوتك بهدوء...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'اتكلم براحتك، هنستخرج المهام بدون فوضى',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('إلغاء')),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('إتمام'),
          ),
        ],
      ),
    );
  }
}
