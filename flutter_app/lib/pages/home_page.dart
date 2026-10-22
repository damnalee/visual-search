import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/search_provider.dart';
import '../theme.dart';
import '../utils/color_map.dart';
import '../widgets/product_card.dart';
import '../widgets/product_sheet.dart';
import '../widgets/shimmer.dart';

const List<String> kSuggestions = [
  'red running shoes',
  'black leather handbag',
  'blue denim jeans',
  'white cotton t-shirt',
  'gold wrist watch',
  'silver earrings',
];

const SliverGridDelegate kGridDelegate =
    SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
  childAspectRatio: 0.72,
  crossAxisSpacing: 16,
  mainAxisSpacing: 16,
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ImagePicker _picker = ImagePicker();

  bool get _cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    final query = (text ?? _controller.text).trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _focus.unfocus();
    context.read<SearchProvider>().searchText(query);
  }

  Future<void> _pick(ImageSource source) async {
    final provider = context.read<SearchProvider>();
    final file = await _picker.pickImage(source: source, maxWidth: 1024);
    if (file == null) return;
    _controller.clear();
    await provider.searchImage(file);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundGlow()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: _Header()),
                    SliverToBoxAdapter(child: _searchPanel(provider, scheme)),
                    SliverToBoxAdapter(child: _colorRow(provider)),
                    if (provider.previewBytes != null)
                      SliverToBoxAdapter(child: _previewStrip(provider, scheme)),
                    ..._body(provider),
                    const SliverToBoxAdapter(child: SizedBox(height: 48)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(SearchProvider provider) {
    if (provider.loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverGrid.builder(
            gridDelegate: kGridDelegate,
            itemCount: 8,
            itemBuilder: (_, __) => const SkeletonCard(),
          ),
        ),
      ];
    }
    if (provider.error != null) {
      return [
        SliverToBoxAdapter(
          child: _StateMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Something went wrong',
            message: provider.error!,
            actionLabel: 'Try again',
            onAction: provider.retry,
          ),
        ),
      ];
    }
    if (!provider.hasSearched) {
      return [SliverToBoxAdapter(child: _suggestions())];
    }
    if (provider.results.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: _StateMessage(
            icon: Icons.search_off_rounded,
            title: 'No matches',
            message: 'Try different words, a clearer photo, or another color.',
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: _resultsHeader(provider)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid.builder(
          gridDelegate: kGridDelegate,
          itemCount: provider.results.length,
          itemBuilder: (context, index) {
            final product = provider.results[index];
            return _Reveal(
              key: ValueKey('${provider.searchVersion}-${product.id}'),
              index: index,
              child: ProductCard(
                product: product,
                isBest: index == 0,
                onTap: () => showProductSheet(context, product),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _searchPanel(SearchProvider provider, ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: kBrand.withValues(alpha: isDark ? 0.25 : 0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Describe what you are looking for',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Search by photo',
            onPressed:
                provider.loading ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.image_outlined),
          ),
          if (_cameraAvailable)
            IconButton(
              tooltip: 'Take a photo',
              onPressed:
                  provider.loading ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
            ),
          const SizedBox(width: 4),
          _GoButton(loading: provider.loading, onTap: _submit),
        ],
      ),
    );
  }

  Widget _colorRow(SearchProvider provider) {
    if (provider.colors.isEmpty) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: provider.colors.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _FilterChip(
                label: 'All colors',
                selected: provider.selectedColor == null,
                onTap: () => provider.setColor(null),
              );
            }
            final color = provider.colors[i - 1];
            return _FilterChip(
              label: color,
              dot: colorFor(color),
              selected: provider.selectedColor == color,
              onTap: () => provider.setColor(color),
            );
          },
        ),
      ),
    );
  }

  Widget _previewStrip(SearchProvider provider, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              provider.previewBytes!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Searching by image',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  provider.previewLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: provider.clear,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _resultsHeader(SearchProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        children: [
          Text(
            '${provider.results.length} matches',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          if (provider.thresholdUsed != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'min score ${provider.thresholdUsed!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _suggestions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRY SEARCHING',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in kSuggestions)
                ActionChip(
                  avatar: const Icon(Icons.north_east_rounded, size: 16),
                  label: Text(s),
                  onPressed: () => _submit(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alpha = isDark ? 0.28 : 0.16;

    Widget blob(Color color, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        );

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -140,
            left: -120,
            child: blob(kBrand.withValues(alpha: alpha), 420),
          ),
          Positioned(
            top: 40,
            right: -160,
            child: blob(kBrandAlt.withValues(alpha: alpha), 380),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(colors: [kBrand, kBrandAlt]),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Visual Search',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [kBrand, kBrandAlt],
            ).createShader(rect),
            child: Text(
              'Search what you see.',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Describe a product or drop in a photo. '
            'CLIP finds the closest matches in the catalog.',
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _GoButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [kBrand, kBrandAlt]),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? dot;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? kBrand : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? kBrand
                    : scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _Reveal({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final capped = index > 12 ? 12 : index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + capped * 45),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}