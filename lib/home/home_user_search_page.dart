import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../official_account.dart';
import '../profile/visitor_profile_sheet.dart';

const Color _searchDark = Color(0xFF000000);
const Color _searchGreen = Color(0xFFFF0000);
const Color _searchCardBg = Color(0xFF1A1A1A);
const Color _searchCardBorder = Color(0xFF303030);
const Color _searchSecondaryBg = Color(0xFF242424);
const Color _searchGray500 = Color(0xFF6B7280);
const Color _searchGray400 = Color(0xFF9CA3AF);

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _recommendedUsers = [];
  bool _loading = false;
  bool _loadingRecommendations = true;
  String? _error;
  String? _recommendationsError;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecommendedUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendedUsers() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_recommended_users',
        params: {
          'p_limit': 20,
        },
      );

      if (!mounted) return;

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      // حساب BDGR الرسمي دايمًا أول واحد في الاقتراحات
      final official = await _officialRow();
      if (!mounted) return;
      if (official != null) {
        rows.removeWhere((r) => OfficialAccount.isOfficial(r['user_id']));
        rows.insert(0, official);
      }

      setState(() {
        _recommendedUsers = rows;
        _loadingRecommendations = false;
        _recommendationsError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('RECOMMENDED USERS RPC ERROR: $e');
      debugPrint('RECOMMENDED USERS RPC STACK TRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _loadingRecommendations = false;
        _recommendationsError =
            'Could not load recommendations.';
      });
    }
  }

  Future<Map<String, dynamic>?> _officialRow() async {
    final id = await OfficialAccount.load();
    if (id == null) return null;
    try {
      final res = await Supabase.instance.client
          .rpc('get_visitor_profile_card', params: {'p_target_user_id': id});
      if (res is! List || res.isEmpty) return null;
      final r = Map<String, dynamic>.from(res.first as Map);
      return {
        'user_id': id,
        'username': r['username'],
        'display_name': r['display_name'],
        'avatar_url': r['avatar_url'],
      };
    } catch (e) {
      debugPrint('official row error: $e');
      return null;
    }
  }

  Widget _avatar(Map<String, dynamic> user, double radius) {
    final avatarUrl = user['avatar_url']?.toString() ?? '';
    final official = OfficialAccount.isOfficial(user['user_id']);
    if (official && avatarUrl.isEmpty) {
      return Container(
        width: radius * 2, height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: OfficialAccount.gold, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: const OfficialAvatarFallback(),
      );
    }
    final circle = CircleAvatar(
      radius: radius,
      backgroundColor: _searchSecondaryBg,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? const Icon(Icons.person_outline, color: _searchGray400)
          : null,
    );
    if (!official) return circle;
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: OfficialAccount.gold),
      child: circle,
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    setState(() {
      _query = query;
      _results = [];
      _error = null;
      _loading = query.length >= 2;
    });

    if (query.length < 2) {
      setState(() => _loading = false);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted || query != _query) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'search_public_users',
        params: {
          'p_query': query,
          'p_limit': 20,
          'p_offset': 0,
        },
      );

      if (!mounted || query != _query) return;

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      setState(() {
        _results = rows;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('SEARCH RPC ERROR: $e');
      debugPrint('SEARCH RPC STACK TRACE: $stackTrace');

      if (!mounted || query != _query) return;

      setState(() {
        _loading = false;
        _error = 'Search failed. Please try again.';
      });
    }
  }

  void _openProfile(Map<String, dynamic> user) {
    final rawId = user['user_id'];
    final userId = rawId is int
        ? rawId
        : int.tryParse(rawId.toString());

    if (userId == null) return;

    // أول شاشة للزائر (الصورة الكبيرة)، ومنها Follow / See Profile
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorProfileSheet(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _searchDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Material(
                    color: _searchCardBg,
                    shape: const CircleBorder(
                      side: BorderSide(
                        color: _searchCardBorder,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      cursorColor: _searchGreen,
                      decoration: InputDecoration(
                        hintText: 'Search by username or name',
                        hintStyle: const TextStyle(
                          color: _searchGray500,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: _searchGray400,
                          size: 21,
                        ),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _controller.clear();
                                  _onSearchChanged('');
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: _searchGray400,
                                  size: 19,
                                ),
                              ),
                        filled: true,
                        fillColor: _searchCardBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                            color: _searchCardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                            color: _searchCardBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                            color: _searchGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _searchGreen),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: _searchGray400),
        ),
      );
    }

    if (_query.length < 2) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          if (_query.isEmpty) ...[
            _buildRecommendedUsers(),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Enter at least 2 characters to search.',
                  style: TextStyle(
                    color: _searchGray500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            _buildRecommendedUsers(),
          ],
        ],
      );
    }

    if (_results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No players found.',
                style: TextStyle(
                  color: _searchGray500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          _buildRecommendedUsers(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        ..._results.map((user) {
          final username = user['username']?.toString() ?? '';
          final displayName =
              user['display_name']?.toString().trim() ?? '';
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: _searchCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _searchCardBorder,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              leading: _avatar(user, 24),
              title: Row(children: [
                Flexible(
                  child: Text(
                    displayName.isNotEmpty ? displayName : username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (OfficialAccount.isOfficial(user['user_id'])) ...[
                  const SizedBox(width: 5),
                  const OfficialBadge(size: 16),
                ],
              ]),
              subtitle: username.isNotEmpty
                  ? Text(
                      '@$username',
                      style: const TextStyle(
                        color: _searchGray500,
                        fontSize: 12,
                      ),
                    )
                  : null,
              trailing: const Icon(
                Icons.chevron_right,
                color: _searchGray400,
              ),
              onTap: () => _openProfile(user),
            ),
          );
        }),
        _buildRecommendedUsers(),
      ],
    );
  }

  Widget _buildRecommendedUsers() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'People You May Know',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingRecommendations)
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  color: _searchGreen,
                ),
              ),
            )
          else if (_recommendationsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Text(
                _recommendationsError!,
                style: const TextStyle(
                  color: _searchGray400,
                  fontSize: 13,
                ),
              ),
            )
          else if (_recommendedUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Text(
                'No recommendations available.',
                style: TextStyle(
                  color: _searchGray500,
                  fontSize: 13,
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recommendedUsers.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final user = _recommendedUsers[index];
                  final username =
                      user['username']?.toString() ?? '';
                  final displayName =
                      user['display_name']?.toString().trim() ?? '';

                  return Material(
                    color: _searchCardBg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openProfile(user),
                      child: Container(
                        width: 112,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _searchCardBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _avatar(user, 28),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName.isNotEmpty
                                        ? displayName
                                        : username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (OfficialAccount.isOfficial(user['user_id'])) ...[
                                  const SizedBox(width: 3),
                                  const OfficialBadge(size: 13),
                                ],
                              ],
                            ),
                            if (username.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _searchGray500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
