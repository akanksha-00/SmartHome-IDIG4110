import 'dart:math' as math;

import 'package:flutter/material.dart';

const authAmber = Color(0xFFFFB923);
const authMuted = Color(0xFFB7BFCC);

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => const Row(children: [
        Icon(Icons.home_outlined, color: authAmber, size: 36),
        SizedBox(width: 14),
        Flexible(
            child: Text('Smart Home',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
      ]);
}

class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        key: const ValueKey('auth-brand-panel'),
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.1, 0.15),
            radius: 1.1,
            colors: [Color(0xFF22272A), Color(0xFF101416)],
          ),
          border: Border(right: BorderSide(color: Color(0xFF202629))),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final padding = constraints.maxWidth >= 760 ? 48.0 : 36.0;
          return SingleChildScrollView(
            child: SizedBox(
              height: math.max(760, constraints.maxHeight),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: padding, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthBrand(),
                    const SizedBox(height: 44),
                    Text('Your home, connected.',
                        style: TextStyle(
                            fontSize: constraints.maxWidth >= 760 ? 44 : 36,
                            height: 1.15,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text('Lighting, safety and comfort in one place.',
                        style: TextStyle(
                            fontSize: 20, height: 1.4, color: authMuted)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/images/authentication/smart_home.png',
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        _Feature(Icons.lightbulb_outline, 'Lighting'),
                        _FeatureDivider(),
                        _Feature(Icons.verified_user_outlined, 'Safety'),
                        _FeatureDivider(),
                        _Feature(Icons.settings_outlined, 'Automations'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: authAmber, size: 30),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 15))),
        ]),
      );
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 36, child: VerticalDivider(width: 24, color: Color(0xFF394044)));
}
