import 'package:flutter/material.dart';

/// Apple 流体风格的弹簧描述。
///
/// Apple 用 damping ratio（阻尼比）+ response（响应秒数）两个设计友好参数，
/// 而非物理三件套（mass/stiffness/damping）。这里把两者打通。
///
/// 约定：
/// - damping 1.0 = 临界阻尼，无过冲，默认 UI 用。
/// - damping < 1.0（如 0.8）= 略带过冲，仅用于带速度的动量交互（flick/throw/drag release）。
/// - response 不是「时长」；弹簧没有固定时长，稳定时间由参数涌现。
class AppSprings {
  AppSprings._();

  /// 默认 UI 弹簧：临界阻尼、无过冲、response 0.4。
  static SpringDescription uiDefault() =>
      fromApple(dampingRatio: 1.0, response: 0.4);

  /// 动量交互弹簧：略带过冲、response 0.3。
  static SpringDescription momentum() =>
      fromApple(dampingRatio: 0.8, response: 0.3);

  /// 把 Apple 的 dampingRatio（阻尼比）+ response（秒）映射到 Flutter 的
  /// SpringDescription（mass/stiffness/damping）。
  ///
  /// 推导（Apple Designing Fluid Interfaces）：
  ///   stiffness = mass / response²
  ///   damping   = 4π · mass · dampingRatio / response
  /// 这里取 mass = 1。
  static SpringDescription fromApple({
    required double dampingRatio,
    required double response,
    double mass = 1.0,
  }) {
    final stiffness = mass / (response * response);
    final damping = (4 * 3.141592653589793 * mass * dampingRatio) / response;
    return SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
  }

  /// reduced-motion 模式下退化为短淡入淡出曲线（200ms）。
  static bool shouldReduceMotion(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.accessibleNavigation || mq.disableAnimations;
  }
}

/// Spring 驱动的 scale + opacity 淡入。从当前显示值开始，可打断。
class SpringFadeIn extends StatefulWidget {
  final Widget child;
  final Key? fadeKey;

  /// 当 [fadeKey] 变化时重新触发淡入（用于状态切换）。
  const SpringFadeIn({super.key, required this.child, this.fadeKey});

  @override
  State<SpringFadeIn> createState() => _SpringFadeInState();
}

class _SpringFadeInState extends State<SpringFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  Key? _lastKey;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _lastKey = widget.fadeKey;
    _controller.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖 MediaQuery（reduced-motion 判断），须在 didChangeDependencies 中读。
    final wasPlaying = _controller.isAnimating;
    _setupCurves();
    if (!wasPlaying && _controller.value < 1.0) {
      _controller.forward();
    }
  }

  void _setupCurves() {
    final reduce = AppSprings.shouldReduceMotion(context);
    if (reduce) {
      _scale = const AlwaysStoppedAnimation(1.0);
      _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
      _controller.duration = const Duration(milliseconds: 200);
    } else {
      _scale = Tween<double>(begin: 0.98, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
      _controller.duration = const Duration(milliseconds: 320);
    }
  }

  @override
  void didUpdateWidget(covariant SpringFadeIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fadeKey != _lastKey) {
      _lastKey = widget.fadeKey;
      // 从当前 presentation 值重新开始，可打断。
      _controller.value = 0;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
