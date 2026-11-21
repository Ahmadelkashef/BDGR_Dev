part of 'profile_page.dart';

// ---------------------------------------------------------------------------
// Pinned tabs delegate
// ---------------------------------------------------------------------------

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate({required this.child, this.height = 70});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: _kBlack,
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFF292929)),
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TabsDelegate oldDelegate) => true;
}
