import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../widgets/app_button.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/onboarding_carousel_item.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      title: 'Track Your Pantry Effortlessly',
      description:
          'Scan barcodes or expiry labels to log groceries instantly and stay ahead of expiration dates.',
      icon: Icons.kitchen_rounded,
    ),
    OnboardingSlide(
      title: 'AI Recipe Suggestions',
      description:
          'Turn what you already have into delicious meals with pantry-aware Gemini AI recipe generator.',
      icon: Icons.auto_awesome_rounded,
    ),
    OnboardingSlide(
      title: 'Smart Shopping & Zero Waste',
      description:
          'Keep your shopping list synced, reduce food waste, and save money effortlessly.',
      icon: Icons.shopping_basket_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDone() {
    ref.read(onboardingControllerProvider.notifier).completeOnboarding();
    context.go('/subscription/paywall');
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingControllerProvider);
    final isLastPage = onboardingState.currentPageIndex == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                child: TextButton(
                  onPressed: _onDone,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            // PageView Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  ref.read(onboardingControllerProvider.notifier).setPageIndex(index);
                },
                itemBuilder: (context, index) {
                  return OnboardingCarouselItem(slide: _slides[index]);
                },
              ),
            ),
            // Indicators and Action Button
            Padding(
              padding: AppSpacing.paddingXl,
              child: Column(
                children: [
                  // Page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isActive = index == onboardingState.currentPageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Next / Get Started button
                  AppButton(
                    label: isLastPage ? 'Get Started' : 'Next',
                    width: double.infinity,
                    onPressed: () {
                      if (isLastPage) {
                        _onDone();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
