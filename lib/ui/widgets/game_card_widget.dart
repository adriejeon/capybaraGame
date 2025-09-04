import 'package:flutter/material.dart';
import '../../game/models/card.dart';
import '../../utils/constants.dart';

/// 게임 카드 위젯
class GameCardWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _buildCard(context),
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
          child: card.isFlipped || card.isMatched
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
          color: card.isMatched ? Colors.green : Colors.blue,
          width: card.isMatched ? 3 : 2,
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
                'assets/${card.imagePath}',
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
          if (card.isMatched)
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
          'assets/images/card-back.jpg',
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
