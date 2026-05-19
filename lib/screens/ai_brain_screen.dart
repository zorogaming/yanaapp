import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/ai_brain_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import 'product_detail_screen.dart';

class AIBrainScreen extends StatefulWidget {
  const AIBrainScreen({super.key});

  @override
  State<AIBrainScreen> createState() => _AIBrainScreenState();
}

class _AIBrainScreenState extends State<AIBrainScreen> {
  static const Color _accentOrange = Color(0xFFD7FC70);
  static const Color _accentGold = Color(0xFFD7FC70);
  static const Color _bg = Color(0xFF0D0D0D);
  static const Color _panel = Color(0xFF171717);

  late Future<AIBrainDashboard> _dashboardFuture;
  int _selectedBikeIndex = 0;

  final List<_BikeProfile> _profiles = const [
    _BikeProfile(
      name: 'Yamaha R15 V4',
      tag: 'Performance Mode',
      score: 92,
      note: 'Inspect brake pads within 14 days',
      efficiency: '22% smarter ride pattern',
      mood: 'Aggressive but stable',
    ),
    _BikeProfile(
      name: 'KTM Duke 200',
      tag: 'Street Control',
      score: 84,
      note: 'Front tire wear is in the medium-risk zone',
      efficiency: '17% lower idle time',
      mood: 'High torque, city ready',
    ),
    _BikeProfile(
      name: 'Royal Enfield Classic 350',
      tag: 'Touring Watch',
      score: 88,
      note: 'Oil check next weekend recommended',
      efficiency: '31% smoother long ride trend',
      mood: 'Comfort-biased cruising',
    ),
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('ai_brain_dashboard');
    _dashboardFuture = AIBrainService.instance.getDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final profile = _profiles[_selectedBikeIndex];
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          'AI Brain',
          style: TextStyle(color: palette.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: Icon(Icons.refresh_rounded, color: palette.textPrimary),
          ),
        ],
      ),
      body: FutureBuilder<AIBrainDashboard>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          final dashboard = snapshot.data;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _heroCard(profile: profile, dashboard: dashboard),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _profiles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = _profiles[index];
                      final isSelected = index == _selectedBikeIndex;
                      return ChoiceChip(
                        label: Text(item.name),
                        selected: isSelected,
                        selectedColor: palette.accent,
                        backgroundColor: palette.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: palette.border),
                        ),
                        onSelected: (_) => setState(() => _selectedBikeIndex = index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting && dashboard == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _metricsGrid(dashboard),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Your Recent Activity',
                    subtitle:
                        'A quick view of what you have been exploring lately.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tokenGroup('Recent searches', dashboard?.recentSearches ?? const []),
                        const SizedBox(height: 14),
                        _tokenGroup(
                          'Recently viewed',
                          dashboard?.recentViewedProducts ?? const [],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Your Ride Snapshot',
                    subtitle: 'A simple summary of what may suit you best right now.',
                    child: Column(
                      children: [
                        _statusRow('Current focus', dashboard?.customerLabel ?? 'Getting Started'),
                        _statusRow('Ride mood', profile.mood),
                        _statusRow('Efficiency gain', profile.efficiency),
                        _statusRow(
                          'Suggested next step',
                          dashboard?.nextBestAction ?? 'Keep exploring to unlock more suggestions',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    title: 'Picked for You',
                    subtitle:
                        'Suggestions based on what you have been browsing and saving.',
                    child: (dashboard?.recommendations.isEmpty ?? true)
                        ? const Text(
                            'More recommendations will appear here as you browse more products.',
                            style: TextStyle(color: Colors.white70, height: 1.4),
                          )
                        : Column(
                            children: (dashboard?.recommendations ?? const <Product>[])
                                .map(_recommendationTile)
                                .toList(),
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heroCard({
    required _BikeProfile profile,
    required AIBrainDashboard? dashboard,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF23140B), Color(0xFF111522), Color(0xFF0A1220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [_accentOrange, _accentGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.black, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rider Intelligence Core',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Smart insights and product suggestions designed around your ride.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip('Live AI', const Color(0xFF22C55E)),
              _chip(profile.tag, _accentOrange),
              _chip(
                dashboard?.customerLabel ?? 'Getting Started',
                const Color(0xFF38BDF8),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dashboard?.intentDescription ?? profile.note,
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dashboard?.nextBestAction ?? 'Your suggestions are improving',
                        style: const TextStyle(
                          color: _accentGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _scoreRing(profile.score),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(AIBrainDashboard? dashboard) {
    final items = dashboard?.metrics ?? const <AIBrainMetric>[];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.03,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.accent),
              ),
              const Spacer(),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _tokenGroup(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Text('Nothing recent yet', style: TextStyle(color: Colors.white54))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(item, style: const TextStyle(color: Colors.white70)),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white60)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendationTile(Product product) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AppCachedImage(
                  url: product.image,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'INR ${product.price}',
                      style: const TextStyle(color: _accentGold, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.shortDescription.replaceAll(RegExp(r'<[^>]*>'), '').trim().isEmpty
                          ? 'This product looks like a strong match for your recent browsing.'
                          : product.shortDescription
                              .replaceAll(RegExp(r'<[^>]*>'), '')
                              .trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _scoreRing(int score) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(_accentOrange),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Score',
                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    final future = AIBrainService.instance.getDashboard();
    setState(() => _dashboardFuture = future);
    await future;
  }
}

class _BikeProfile {
  const _BikeProfile({
    required this.name,
    required this.tag,
    required this.score,
    required this.note,
    required this.efficiency,
    required this.mood,
  });

  final String name;
  final String tag;
  final int score;
  final String note;
  final String efficiency;
  final String mood;
}
