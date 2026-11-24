import 'package:zing/config/business_config.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

class CompanyNavDrawer extends StatelessWidget {
  const CompanyNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // Drawer Header with white gradient and logo
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade200], // White gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Company Logo with subtle shadow
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: const DecorationImage(
                        image: AssetImage('assets/images/zing.png'), // Your company logo path
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          spreadRadius: 2,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Company Name with increased font size
                  const Text(
                    'ZING',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.black, // Black text for contrast
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Animated ListTiles for company details with improved UI
            _buildAnimatedListTile(
              delay: 300,
              icon: Icons.phone,
              title: 'Phone: +94 76 673 789',
              onTap: () => _launchURL('tel:${BusinessConfig.companyPhoneDial}'),
            ),


            // TikTok link
            _buildAnimatedListTile(
              delay: 600,
              icon: Icons.video_library,
              title: 'TikTok: @company',
              onTap: () => _launchURL('https://www.tiktok.com/@zing.official_?_t=8qi5IDOzsPg&_r=1'),
            ),

            Divider(color: Colors.grey.shade300), // Light gray divider

            // About Us with a clear CTA
            _buildAnimatedListTile(
              delay: 800,
              icon: Icons.info_outline,
              title: 'About Us',
              onTap: () {
                // Navigate to About Us page
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedListTile({
    required int delay,
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return FadeInLeft(
      delay: Duration(milliseconds: delay),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade300, // Light gray circle
          child: Icon(icon, color: Colors.black), // Black icon for contrast
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.black, // Black text for contrast
          ),
        ),
        onTap: onTap,
        tileColor: Colors.transparent, // Transparent background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }
}