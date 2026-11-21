part of 'profile_page.dart';

extension _ProfileHistoryTab on _ProfilePageState {
  Widget _buildHistoryHero() {
    return _SectionCard(
      clip: true,
      child: Column(
        children: [
          SizedBox(
            height: 96,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=700&q=85',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: _kSecondaryBg),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kRed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'COMPLETED',
                      style: _s(9, FontWeight.w700, Colors.white, height: 1.5),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 12,
                  child: Text(
                    'Cairo Football Cup',
                    style: _s(14, FontWeight.w900, Colors.white, height: 1.43),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Football · Team Competition',
                      style: _s(10, FontWeight.w400, _kGray500, height: 1.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.group, size: 11, color: _kRed),
                          const SizedBox(width: 4),
                          Text(
                            '32 teams',
                            style:
                                _s(11, FontWeight.w400, _kGray300, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'FINAL RANK',
                      style: _s(9, FontWeight.w400, _kGray500, height: 1.5),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#2 ',
                          style: _s(18, FontWeight.w900, Colors.white,
                              height: 1.55),
                        ),
                        const Icon(Icons.military_tech,
                            size: 14, color: _kRed),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _detailRows([
              (Icons.sports, 'Format', '5 vs 5'),
              (Icons.place, 'Location', 'Nasr City Sports Club'),
              (Icons.emoji_events, 'Winner', 'Team Phoenix'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _historyRow({
    required IconData icon,
    required bool highlight,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String rankLabel,
    required String rank,
    List<(IconData, String, String)> details = const [],
  }) {
    final row = Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: highlight
                  ? _kRed.withOpacity(0.10)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 20, color: highlight ? _kRed : _kGray300),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _s(12, FontWeight.w700, Colors.white, height: 1.33),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: _s(10, FontWeight.w400, _kGray500, height: 1.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    status,
                    style: _s(9, FontWeight.w700, statusColor, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rankLabel,
                style: _s(9, FontWeight.w400, _kGray500, height: 1.5),
              ),
              Text(
                rank,
                style: _s(18, FontWeight.w900, Colors.white, height: 1.55),
              ),
            ],
          ),
        ],
    );

    return _SectionCard(
      padding: const EdgeInsets.all(16),
      child: details.isEmpty
          ? row
          : Column(
              children: [
                row,
                const SizedBox(height: 12),
                _detailRows(details),
              ],
            ),
    );
  }
}
