import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../game/models/card.dart';
import '../../utils/constants.dart';

/// 게임 카드 위젯
class GameCardWidget extends StatefulWidget {
  final GameCard card;
  final VoidCallback onTap;
  final AnimationController flipAnimation;

  const GameCardWidget({
    super.key,
    required this.card,
    required this.onTap,
    required this.flipAnimation,
  });

  @override
  State<GameCardWidget> createState() => _GameCardWidgetState();
}

class _GameCardWidgetState extends State<GameCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _removeController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _removeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 흔들림 애니메이션
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.1, end: 0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: -0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.1, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(
      parent: _removeController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    // 크기 축소 애니메이션
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _removeController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInBack),
      ),
    );

    // 투명도 애니메이션
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _removeController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didUpdateWidget(GameCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 카드가 제거 상태로 변경되면 애니메이션 시작
    if (!oldWidget.card.isRemoving && widget.card.isRemoving) {
      _removeController.forward().then((_) {
        // 애니메이션 완료 후 상태 업데이트를 위해 setState 호출
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _removeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 제거 중이 아니면 일반 카드 표시
    if (!widget.card.isRemoving) {
      return GestureDetector(
        onTap: widget.onTap,
        child: _buildCard(context),
      );
    }

    // 제거 애니메이션 중이거나 완료된 경우
    return AnimatedBuilder(
      animation: _removeController,
      builder: (context, child) {
        // 애니메이션이 완료되면 빈 위젯 반환
        if (_removeController.isCompleted) {
          return const SizedBox.shrink();
        }
        
        return Transform.rotate(
          angle: _shakeAnimation.value * 0.3,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedSwitcher(
          duration: GameConstants.cardFlipDuration,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: widget.card.isFlipped || widget.card.isMatched
              ? _buildCardFront()
              : _buildCardBack(),
        ),
      ),
    );
  }

  Widget _buildCardFront() {
    return Container(
      key: const ValueKey('front'),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: widget.card.isMatched ? Colors.green : Colors.blue,
          width: widget.card.isMatched ? 3 : 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // 카피바라 이미지
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/${widget.card.imagePath}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 매칭 완료 오버레이
          if (widget.card.isMatched)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 30,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      key: const ValueKey('back'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/card-back.webp',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
