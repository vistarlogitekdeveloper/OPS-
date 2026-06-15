import 'package:flutter/material.dart';

import '../theme/vistar.dart';

/// Text rendered with the ribbon gradient via ShaderMask. Reserve for
/// KPI numbers, pitch headlines, and brand callouts.
class RibbonText extends StatelessWidget {
  const RibbonText(this.data, {super.key, this.style, this.textAlign});

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.headlineSmall;
    return ShaderMask(
      shaderCallback: (rect) => Vistar.ribbon.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(
        data,
        textAlign: textAlign,
        style: base?.copyWith(color: Colors.white),
      ),
    );
  }
}
