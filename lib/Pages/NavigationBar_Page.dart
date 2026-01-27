import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:waste_management/Pages/Home_Page.dart';

import 'Camera/Camera_Page.dart';
import 'Profile_Page.dart';

class NavigationBarPage extends StatefulWidget {
  const NavigationBarPage({super.key});

  @override
  State<NavigationBarPage> createState() => _NavigationBarPageState();
}

class _NavigationBarPageState extends State<NavigationBarPage> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const HomePage(),
    const ProfilePage(),
  ];

  void onTabSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void onCameraPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
  }

  Widget _svgIcon(String asset, Color color) {
    return SvgPicture.asset(
      asset,
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: pages[selectedIndex],
      bottomNavigationBar: SizedBox(
        height: 60,
        child: StylishBottomBar(
          option: AnimatedBarOptions(
            iconStyle: IconStyle.Default,
            barAnimation: BarAnimation.fade,
          ),
          items: [
            BottomBarItem(
              icon: _svgIcon(
                'lib/assets/images/home.svg',
                Colors.grey,
              ),
              selectedIcon: _svgIcon(
                'lib/assets/images/home.svg',
                Colors.blue,
              ),
              title: const Text(
                'Home',
                style: TextStyle(fontSize: 12),
              ),
              selectedColor: Colors.blue,
              unSelectedColor: Colors.grey,
            ),
            BottomBarItem(
              icon: _svgIcon(
                'lib/assets/images/profile.svg',
                Colors.grey,
              ),
              selectedIcon: _svgIcon(
                'lib/assets/images/profile.svg',
                Colors.blue,
              ),
              title: const Text(
                'Profile',
                style: TextStyle(fontSize: 12),
              ),
              selectedColor: Colors.blue,
              unSelectedColor: Colors.grey,
            ),
          ],
          fabLocation: StylishBarFabLocation.center,
          notchStyle: NotchStyle.circle,
          hasNotch: true,
          backgroundColor: Colors.white.withAlpha(180),
          currentIndex: selectedIndex,
          onTap: onTabSelected,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          elevation: 6,
          shape: const CircleBorder(),
          backgroundColor: Colors.blue,
          onPressed: onCameraPressed,
          child: SvgPicture.asset(
            'lib/assets/images/camera.svg',
            width: 26,
            height: 26,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
