import 'dart:async';
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../providers/face_search_provider.dart';

class FaceSearchScanProgressScreen extends ConsumerStatefulWidget {
  final File file;
  
  const FaceSearchScanProgressScreen({super.key, required this.file});

  @override
  ConsumerState<FaceSearchScanProgressScreen> createState() =>
      _FaceSearchScanProgressScreenState();
}

class _FaceSearchScanProgressScreenState
    extends ConsumerState<FaceSearchScanProgressScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  bool _cancelled = false;
  bool _navigated = false;
  bool _searchStarted = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_searchStarted) {
      _searchStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch();
      });
    }
  }

  Future<void> _runSearch() async {
    final success = await ref.read(faceSearchProvider.notifier).selectSelfieFile(widget.file);
    if (!mounted || _cancelled) return;
    
    if (success) {
      _navigateToResultsOnce();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _navigateToResultsOnce() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.faceSearchResults);
  }

  void _cancel() {
    if (_cancelled) return;
    setState(() => _cancelled = true);
    _scanController.stop();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.faceSearchLanding,
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faceSearchProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Scanning…',
          showBack: false,
          actions: [
            IconButton(
              tooltip: 'Cancel scan',
              icon: const Icon(Icons.close_rounded),
              onPressed: _cancel,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScanCard(state),
                const SizedBox(height: AppSpacing.lg),
                if (state.error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanCard(FaceSearchState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedScannerIcon(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.statusMessage,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Matching your selfie against shared albums…',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtitle,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedScannerIcon() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (_, __) {
                return const Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
