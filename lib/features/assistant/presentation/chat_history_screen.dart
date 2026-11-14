import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_bottom_nav.dart';
import '../../../shared/widgets/handelha_header.dart';
import 'assistant_providers.dart';

/// شاشة سجل المحادثات.
class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatSessionProvider).refreshConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatUpdatedAt(DateTime dt, bool isEn) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    if (target == today) return ArabicFormatters.timeOfDayAr(dt);
    if (target == today.subtract(const Duration(days: 1))) {
      return isEn ? 'Yesterday' : 'أمس';
    }
    return ArabicFormatters.dateShort(dt);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final session = ref.watch(chatSessionProvider);

    final filtered = session.conversations.where((conv) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      final title = ArabicFormatters.trData(conv.title).toLowerCase();
      return conv.title.toLowerCase().contains(q) || title.contains(q);
    }).toList();

    return Scaffold(
      extendBody: true,
      body: HandelhaAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 114),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandelhaHeader(
                  title: isEn ? 'Chat History' : 'سجل المحادثات',
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                ),

                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 14.5, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: isEn
                        ? 'Search by keyword or topic...'
                        : 'دوّر بكلمة أو موضوع...',
                    filled: true,
                    fillColor: c.surface,
                    suffixIcon: Icon(
                      Icons.search_rounded,
                      color: c.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // New conversation CTA
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      await ref.read(chatSessionProvider).newConversation();
                      if (!mounted) return;
                      if (router.canPop()) {
                        router.pop();
                      } else {
                        router.go('/chat');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEn ? 'New Conversation' : 'محادثة جديدة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.textOnPrimary,
                          ),
                        ),
                        Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: c.textOnPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                Text(
                  isEn ? 'Recent Conversations' : 'آخر محادثاتك',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      _query.trim().isEmpty
                          ? (isEn
                              ? 'No past conversations yet. Start a new chat with Handelha!'
                              : 'لسه مفيش محادثات سابقة. ابدأ محادثة جديدة مع هندلها!')
                          : (isEn
                              ? 'No results match your search.'
                              : 'مفيش نتائج مطابقة للبحث ده.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textSecondary,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final conv = filtered[i];
                            final active =
                                conv.id == session.currentConversationId;
                            return Material(
                              color: active ? c.primarySoft : c.surface,
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () async {
                                  final router = GoRouter.of(context);
                                  await ref
                                      .read(chatSessionProvider)
                                      .selectConversation(conv.id);
                                  if (!mounted) return;
                                  if (router.canPop()) {
                                    router.pop();
                                  } else {
                                    router.go('/chat');
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: active
                                        ? null
                                        : Border.all(color: c.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: active
                                              ? c.surface
                                              : c.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 20,
                                          color: c.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              conv.title.trim().isEmpty
                                                  ? (isEn
                                                      ? 'Chat with Handelha'
                                                      : 'محادثة مع هندلها')
                                                  : ArabicFormatters.trData(
                                                      conv.title,
                                                    ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: c.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              active
                                                  ? (isEn
                                                      ? 'Current conversation'
                                                      : 'المحادثة الحالية')
                                                  : (isEn
                                                      ? 'Tap to resume this conversation'
                                                      : 'اضغط للعودة لهذه المحادثة'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: c.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _formatUpdatedAt(
                                          conv.updatedAt,
                                          isEn,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),

                const SizedBox(height: 22),
                Text(
                  isEn
                      ? 'Every idea has a place — return to it whenever you like.'
                      : 'كل فكرة ليها مكان، ارجع لها وقت ما تحب.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const HandelhaBottomNav(currentIndex: 3),
    );
  }
}

