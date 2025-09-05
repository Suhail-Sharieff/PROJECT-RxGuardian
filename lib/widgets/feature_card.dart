import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

// A dedicated widget for feature cards that adapts to the current theme
// and shows a hover effect on desktop/web.
class FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Get the current theme from the context.
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16), // Ensures ripple effect matches shape
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // Use the theme's card color for the background.
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              // Show a primary color border on hover.
              color: _isHovered ? kPrimaryColor : theme.dividerColor.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              // Show a shadow on hover, using a theme-aware color.
              if (_isHovered)
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.15),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Use a semi-transparent primary color for the icon background.
                  color: kPrimaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                // The icon color remains the primary color.
                child: Icon(widget.icon, size: 32, color: kPrimaryColor),
              ),
              const SizedBox(height: 24), // Using a constant for spacing
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  // Use the theme's color for the main text.
                  color: theme.textTheme.titleMedium?.color,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  // Use the theme's color for secondary text.
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
