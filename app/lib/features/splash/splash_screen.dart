import 'package:antigua_business_map/widgets/dadliplug_logo.dart';
import 'package:flutter/material.dart';

/// The Dadliplug splash, from the design: logo, name, tagline and the three
/// promises over a sea-blue background.
///
/// The design puts a photo of the coast behind it; the supplied splash image
/// is 223x466, too small to fill a phone without visible blur. Until a
/// full-size version exists, the background is a sky-to-sea gradient in the
/// colours sampled from that image. Its top colour matches the native launch
/// screen, so the hand-off is seamless.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Shared with `android/.../launch_background.xml` so the native launch
  /// screen and this one meet without a flash.
  static const Color top = Color(0xFF0565B9);

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;

    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            top,
            Color(0xFF3681BA),
            Color(0xFF0D87B8),
            Color(0xFF046586),
            Color(0xFF03293C),
          ],
          stops: [0, 0.35, 0.6, 0.8, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Spacer(flex: 3),
            DadliplugMark(size: 150),
            SizedBox(height: 20),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Dadli'),
                  TextSpan(
                    text: 'plug',
                    style: TextStyle(color: DadliplugColors.lightGreen),
                  ),
                ],
              ),
              style: TextStyle(
                color: white,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              DadliplugLogo.tagline,
              style: TextStyle(
                color: white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(flex: 4),
            Text(
              'Discover local businesses.\n'
              'Find great deals.\n'
              'Support your community.',
              textAlign: TextAlign.center,
              style: TextStyle(color: white, fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

/// Shows [SplashScreen] over the app for [duration], then fades it out.
///
/// An overlay rather than a route, so the router's own first screen (and any
/// deep link) is already built underneath when the splash lifts.
class SplashGate extends StatefulWidget {
  const SplashGate({
    required this.child,
    this.duration = const Duration(milliseconds: 1600),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _visible = true;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.duration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_removed)
          IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              onEnd: () => setState(() => _removed = true),
              child: const SplashScreen(),
            ),
          ),
      ],
    );
  }
}
