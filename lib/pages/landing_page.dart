import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/routes.dart';
import 'home_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});
  static const route_name = landing_route;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(context),
            kVerticalSpaceLarge,
            _buildFeaturesSection(context),
            kVerticalSpaceLarge,
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // --- HERO SECTION ---
  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative Blobs
          _buildGlassmorphicBlob(
            top: -100,
            left: -100,
            color: kPrimaryColor.withOpacity(0.2),
          ),
          _buildGlassmorphicBlob(
            bottom: -150,
            right: -150,
            color: Colors.blueAccent.withOpacity(0.2),
          ),

          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Text(
                    "RxGuardian",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Advanced pharmacy management app", // <-- Subtitle updated here
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: kSecondaryTextColor,
                      fontSize: 22,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      backgroundColor: kPrimaryColor,
                      foregroundColor: kBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamed(HomePage.route_name);
                    },
                    child: Text(
                      "Get Started Free",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for decorative shapes in the hero section
  Widget _buildGlassmorphicBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        height: 300,
        width: 300,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  // --- FEATURES SECTION ---
  Widget _buildFeaturesSection(BuildContext context) {
    // <-- Features list updated for a pharmacy management system
    final features = [
      {
        "icon": Icons.inventory_2_rounded,
        "title": "Inventory Management",
        "desc":
            "Track stock levels, manage drug expiration, and reorder automatically.",
      },
      {
        "icon": Icons.receipt_long_rounded,
        "title": "Prescription Processing",
        "desc":
            "Digitize and manage prescriptions, verify patient details, and handle refills.",
      },
      {
        "icon": Icons.point_of_sale_rounded,
        "title": "Billing & Invoicing",
        "desc":
            "Generate accurate invoices, process payments, and manage insurance claims.",
      },
      {
        "icon": Icons.analytics_rounded,
        "title": "Reporting & Analytics",
        "desc":
            "Gain insights with detailed reports on sales, inventory, and profits.",
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 24,
        spacing: 24,
        children: features
            .map(
              (f) => FeatureCard(
                icon: f["icon"] as IconData,
                title: f["title"] as String,
                description: f["desc"] as String,
              ),
            )
            .toList(),
      ),
    );
  }

  // --- FOOTER SECTION ---
  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: kCardColor,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return isWide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _footerContent(isWide: true),
                )
              : Column(children: _footerContent(isWide: false));
        },
      ),
    );
  }

  List<Widget> _footerContent({required bool isWide}) {
    return [
      Text(
        "© 2025 RxGuardian. All rights reserved.", // <-- Footer text updated
        style: GoogleFonts.poppins(color: kSecondaryTextColor),
      ),
      if (!isWide) const SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 10,
        children: const [
          _FooterLink(text: "Privacy Policy"),
          _FooterLink(text: "Terms of Service"),
          _FooterLink(text: "Contact Us"),
        ],
      ),
    ];
  }
}

// --- REUSABLE WIDGETS ---

// A dedicated widget for feature cards to handle hover effects
class FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? kPrimaryColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 4,
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 32, color: kPrimaryColor),
            ),
            kVerticalSpaceMedium,
            Text(
              widget.title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: kSecondaryTextColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A simple text link for the footer with a hover effect
class _FooterLink extends StatefulWidget {
  final String text;
  const _FooterLink({required this.text});

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Text(
        widget.text,
        style: GoogleFonts.poppins(
          color: _isHovered ? kPrimaryColor : Colors.white70,
        ),
      ),
    );
  }
}