import 'package:flutter/material.dart';

class TuntonApp extends StatelessWidget {
  const TuntonApp({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tunton',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: home,
  );

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF24594A),
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFA2D6BE) : const Color(0xFF24594A),
          onPrimary: dark ? const Color(0xFF122C22) : Colors.white,
          surface: dark ? const Color(0xFF202326) : Colors.white,
          surfaceContainerLowest: dark ? const Color(0xFF17191B) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xFF292C2F)
              : const Color(0xFFF0F2EF),
          surfaceContainer: dark
              ? const Color(0xFF292C2F)
              : const Color(0xFFF0F2EF),
          onSurface: dark ? const Color(0xFFF0F2F1) : const Color(0xFF202723),
          onSurfaceVariant: dark
              ? const Color(0xFFBCC3BE)
              : const Color(0xFF4A544E),
          outlineVariant: dark
              ? const Color(0xFF454B47)
              : const Color(0xFFDDE2DD),
        );
    final text =
        const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -1.2,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.8,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.55),
          bodyMedium: TextStyle(fontSize: 14, height: 1.5),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ).apply(
          fontFamily: 'Inter',
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Inter',
      textTheme: text,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF17191B)
          : const Color(0xFFF8F9F6),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF17191B)
            : const Color(0xFFF8F9F6),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 64),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: scheme.onSurface, width: 4),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 64),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.onSurface, width: 4),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          elevation: 0,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(width: 4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface,
        thickness: 4,
      ),
    );
  }
}

/// Shared chrome for the four approved photo-to-route screens.
class TuntonScaffold extends StatelessWidget {
  const TuntonScaffold({
    super.key,
    required this.step,
    required this.child,
    this.backLabel,
    this.onBack,
  });
  final int step;
  final Widget child;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary,
                border: Border.all(color: colors.onSurface, width: 3),
                boxShadow: [
                  BoxShadow(color: colors.onSurface, offset: const Offset(4, 4)),
                ],
              ),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'TUNTON',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: colors.onSurface, width: 3),
                color: colors.surface,
              ),
              child: Icon(
                Icons.location_on,
                color: colors.onSurface,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _JourneyProgress(step: step),
                  const SizedBox(height: 24),
                  if (onBack != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, size: 20),
                        label: Text(backLabel?.toUpperCase() ?? 'BACK'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyProgress extends StatelessWidget {
  const _JourneyProgress({required this.step});
  final int step;
  static const labels = ['PHOTO', 'CONFIRM', 'START', 'ROUTE'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step ${step + 1} of 4: ${labels[step]}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(12) > 16;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 3 ? 0 : 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: index <= step
                                    ? colors.primary
                                    : colors.surface,
                                border: Border.all(
                                  color: colors.onSurface,
                                  width: 2,
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: 8),
                              Text(
                                labels[index],
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      color: index == step
                                          ? colors.onSurface
                                          : colors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (compact) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${step + 1} / 4 · ${labels[step]}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class JourneyMessage extends StatelessWidget {
  const JourneyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.onSurface, width: 4),
          boxShadow: [
            BoxShadow(
              color: colors.onSurface,
              offset: const Offset(6, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.onSurface, size: 36),
            const SizedBox(height: 16),
            Text(
              title.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
