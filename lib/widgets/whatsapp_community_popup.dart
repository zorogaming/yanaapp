import 'package:flutter/material.dart';

const _communityLime = Color(0xFFC8FF28);

class WhatsappCommunityPopup extends StatelessWidget {
  const WhatsappCommunityPopup({super.key, required this.onJoinNow});

  final VoidCallback onJoinNow;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          child: AspectRatio(
            aspectRatio: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Container(
                width: 400,
                height: 400,
                clipBehavior: Clip.antiAlias,
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _communityLime, width: 1.5),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF050704),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _communityLime.withValues(alpha: .22),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/branding/community_rider.png',
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xD9000000), Color(0x18000000)],
                          stops: [0, .8],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 19, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 170,
                            height: 44,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _communityLime.withValues(alpha: .75),
                              ),
                            ),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 17),
                          const Text('Join Our', style: _headline),
                          const Text(
                            'WhatsApp',
                            style: TextStyle(
                              color: _communityLime,
                              fontSize: 34,
                              height: 1.05,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text('Community!', style: _headline),
                          const SizedBox(height: 8),
                          const SizedBox(
                            width: 250,
                            child: Text(
                              'Get the latest updates, exclusive offers,\nnew arrivals and connect with fellow riders.',
                              style: TextStyle(
                                color: Color(0xFFD0D0D0),
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Row(
                            children: [
                              Expanded(
                                child: _CommunityBenefit(
                                  icon: Icons.sell_outlined,
                                  label: 'Offers',
                                  detail: 'Exclusive\nDeals',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: _CommunityBenefit(
                                  icon: Icons.sports_motorsports_outlined,
                                  label: 'Gear',
                                  detail: 'New\nArrivals',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: _CommunityBenefit(
                                  icon: Icons.chat_outlined,
                                  label: 'Chat',
                                  detail: 'Connect\nwith Riders',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: onJoinNow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _communityLime,
                                foregroundColor: Colors.black,
                                elevation: 8,
                                shadowColor: _communityLime.withValues(
                                  alpha: .5,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE9FFB0),
                                  width: 1.5,
                                ),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_rounded, size: 23),
                                  SizedBox(width: 12),
                                  Text(
                                    'JOIN NOW',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(Icons.arrow_forward_rounded, size: 26),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .85),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: _communityLime.withValues(alpha: .35),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 26),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _headline = TextStyle(
    color: Colors.white,
    fontSize: 30,
    height: 1.05,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w900,
  );
}

class _CommunityBenefit extends StatelessWidget {
  const _CommunityBenefit({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xEA080B05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _communityLime.withValues(alpha: .65)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xC94D6505), Color(0xF2050704), Color(0xF2050704)],
          stops: [0, .24, 1],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _communityLime, size: 27),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 10,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
