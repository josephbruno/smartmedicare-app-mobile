import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';

class AuthMarketingPanel extends StatelessWidget {
  const AuthMarketingPanel({
    super.key,
    this.compact = false,
    this.panelHeight,
  });
  final bool compact;

  /// Explicit height passed from the parent (login_screen.dart).
  /// When provided, the Stack gets a hard-bounded SizedBox wrapper
  /// so that [Positioned.fill] and [StackFit] never see infinite height.
  final double? panelHeight;

  @override
  Widget build(BuildContext context) {
    if (compact) return const _CompactMarketingPanel();

    const copySize = 40.0;
    final isShort = (panelHeight ?? 640) < 700;

    // The Stack MUST have bounded constraints.  We achieve this by wrapping
    // it in a SizedBox whose height comes from the caller (login_screen.dart
    // passes the hard-clamped cardH).  Using LayoutBuilder here is wrong
    // because LayoutBuilder reports loose (unbounded) cross-axis constraints
    // when it is placed inside a Column or Row in a scroll context.
    Widget panel = SizedBox(
      // This SizedBox is the Stack's DIRECT parent with a finite height.
      // DecoratedBox is a proxy widget that would pass constraints through,
      // so we need the SizedBox here, not around the outer DecoratedBox.
      width: double.infinity,
      height: panelHeight ?? 640,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF031B52), Color(0xFF052C75), Color(0xFF00143F)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Decorative circle ring ──────────────────────────────────────
            Positioned(
              top: 105,
              right: -265,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x3D42A5FF), width: 64),
                ),
              ),
            ),
            // ── Red/purple diagonal stripe at bottom ────────────────────────
            Positioned(
              right: -70,
              bottom: -42,
              child: Transform.rotate(
                angle: -.18,
                child: Container(
                  height: 92,
                  width: 430,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0x00E60018),
                      Color(0xDDE60018),
                      Color(0xFF3B0CA3)
                    ]),
                  ),
                ),
              ),
            ),
            // ── Hero photo ─────────────────────────────────────────────────
            Positioned(
              right: 0,
              width: 900,
              bottom: isShort ? 60 : 80,
              top: isShort ? 120 : 160,
              child: _HeroPhoto(),
            ),
            // ── Content (clipped to panel bounds) ──────────────────────────
            // SingleChildScrollView with NeverScrollableScrollPhysics silences
            // RenderFlex overflow: the Column can be its natural (tall) size;
            // ClipRect + Positioned.fill ensure only the visible area shows.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  50,
                  isShort ? 20 : 32,
                  50,
                  isShort ? 16 : 24,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Brand(),
                            SizedBox(height: isShort ? 14 : 22),
                            const _CareChoice(),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Eyebrow(),
                            SizedBox(height: isShort ? 8 : 12),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: isShort ? 30.0 : copySize,
                                  height: 1.06,
                                  letterSpacing: -1.5,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Complete care\nmanagement for\n',
                                  ),
                                  TextSpan(
                                    text: 'every\npatient.',
                                    style: TextStyle(color: Color(0xFF42A5FF)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isShort ? 8 : 14),
                            SizedBox(
                              width: 460,
                              child: Text(
                                'Patients, appointments, clinical records, pharmacy, '
                                'inventory and billing for Human and Veterinary healthcare.',
                                maxLines: isShort ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xDDF3F7FF),
                                  fontSize: isShort ? 11 : 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ServiceBar(),
                            SizedBox(height: isShort ? 12 : 18),
                            const Row(
                              children: [
                                _Dot(active: true),
                                SizedBox(width: 6),
                                _Dot(),
                                SizedBox(width: 6),
                                _Dot(),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ], // Stack children
        ), // Stack
      ), // DecoratedBox
    ); // SizedBox

    return panel;
  }
}

// ---------------------------------------------------------------------------
// Hero photo — uses the pet-hero asset; falls back gracefully if missing.
// ---------------------------------------------------------------------------
class _HeroPhoto extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const assetPath = 'assets/branding/clinic-hero-transparent.png';
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF031B52), Colors.transparent],
        stops: [0.0, 0.35],
      ).createShader(rect),
      blendMode: BlendMode.dstOut,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xFF00143F)],
          stops: [0.55, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstOut,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.bottomRight,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CompactMarketingPanel extends StatelessWidget {
  const _CompactMarketingPanel();

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 390),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF031B52), Color(0xFF052C75), Color(0xFF00143F)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            FittedBox(alignment: Alignment.centerLeft, child: _Brand()),
            SizedBox(height: 28),
            _Eyebrow(compact: true),
            SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 31,
                    height: 1.08),
                children: [
                  TextSpan(text: 'Complete care\nmanagement for '),
                  TextSpan(
                      text: 'every patient.',
                      style: TextStyle(color: Color(0xFF42A5FF))),
                ],
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Patients, appointments, clinical records, pharmacy, inventory and billing for every clinic.',
              style: TextStyle(
                  color: Color(0xDDF3F7FF), fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 24),
            Row(children: [
              _Dot(active: true),
              SizedBox(width: 6),
              _Dot(),
              SizedBox(width: 6),
              _Dot()
            ]),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Brand row: logo + "SmartMediCare" + tagline
// ---------------------------------------------------------------------------
class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(children: [
        AppLogo(size: 62, borderRadius: 0),
        SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(
              style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  color: Colors.white,
                  letterSpacing: -1.3),
              children: [
                TextSpan(
                    text: 'Smart',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: 'MediCare')
              ])),
          SizedBox(height: 8),
          Text('SMARTER CLINICS   •   HEALTHIER LIVES',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.7,
                  color: Color(0xCCFFFFFF))),
        ]),
      ]);
}

// ---------------------------------------------------------------------------
// Care-choice row: Human Care | logo tile | Veterinary Care
// ---------------------------------------------------------------------------
class _CareChoice extends StatelessWidget {
  const _CareChoice();
  @override
  Widget build(BuildContext context) => Row(children: const [
        Expanded(
            child: _CareCard(
                icon: Icons.person_outline_rounded,
                title: 'Human\nCare',
                sub: 'Clinics • Hospitals',
                red: true)),
        SizedBox(width: 14),
        _LogoTile(),
        SizedBox(width: 14),
        Expanded(
            child: _CareCard(
                icon: Icons.pets_outlined,
                title: 'Veterinary\nCare',
                sub: 'Animal Clinics')),
      ]);
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();
  @override
  Widget build(BuildContext context) => Container(
      width: 94,
      height: 94,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1F7EFF), width: 3)),
      child: const Center(child: AppLogo(size: 68, borderRadius: 0)));
}

class _CareCard extends StatelessWidget {
  const _CareCard(
      {required this.icon,
      required this.title,
      required this.sub,
      this.red = false});
  final IconData icon;
  final String title;
  final String sub;
  final bool red;
  @override
  Widget build(BuildContext context) => Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0x332D66BD),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0x33FFFFFF))),
      child: Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundColor:
                red ? const Color(0xFFE60018) : const Color(0xFF456FE1),
            child: Icon(icon, color: Colors.white, size: 19)),
        const SizedBox(width: 9),
        Expanded(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xBFFFFFFF), fontSize: 10))
            ])),
        const Icon(Icons.arrow_forward_rounded,
            color: Color(0xCCFFFFFF), size: 16),
      ]));
}

// ---------------------------------------------------------------------------
// Eyebrow: "— ONE PLATFORM. EVERY CLINIC."
// ---------------------------------------------------------------------------
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox(
            width: 30, child: Divider(color: Color(0xFFE60018), thickness: 3)),
        const SizedBox(width: 14),
        Expanded(
            child: Text('ONE PLATFORM. EVERY CLINIC.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: compact ? 1.1 : 1.7))),
      ]);
}

// ---------------------------------------------------------------------------
// Service bar — 5 items matching the screenshot
// ---------------------------------------------------------------------------
class _ServiceBar extends StatelessWidget {
  const _ServiceBar();
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: const Color(0x7008245C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33FFFFFF))),
      child: const Row(children: [
        Expanded(
            child: _Service(
                icon: Icons.calendar_month_outlined,
                label: 'OPD & IPD',
                sub: 'Management')),
        Expanded(
            child: _Service(
                icon: Icons.pets_outlined,
                label: 'Veterinary',
                sub: 'Practice')),
        Expanded(
            child: _Service(
                icon: Icons.receipt_long_outlined,
                label: 'POS &',
                sub: 'Billing')),
        Expanded(
            child: _Service(
                icon: Icons.medication_outlined,
                label: 'Pharmacy &',
                sub: 'Inventory')),
        Expanded(
            child: _Service(
                icon: Icons.supervised_user_circle_outlined,
                label: 'Multi-Branch',
                sub: 'Support')),
      ]));
}

class _Service extends StatelessWidget {
  const _Service({required this.icon, required this.label, required this.sub});
  final IconData icon;
  final String label;
  final String sub;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF3B5FC0),
              child: Icon(icon, color: Colors.white, size: 17)),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xCFFFFFFF), fontSize: 9)),
        ],
      ));
}

// ---------------------------------------------------------------------------
// Dot indicator
// ---------------------------------------------------------------------------
class _Dot extends StatelessWidget {
  const _Dot({this.active = false});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
      width: active ? 25 : 17,
      height: 4,
      decoration: BoxDecoration(
          color: active ? const Color(0xFFE60018) : const Color(0x99FFFFFF),
          borderRadius: BorderRadius.circular(9)));
}
