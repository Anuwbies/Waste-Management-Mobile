import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

import 'Profile_Page.dart';

class NavigationBarPage extends StatefulWidget {
  const NavigationBarPage({super.key});

  @override
  State<NavigationBarPage> createState() => _NavigationBarPageState();
}

class _NavigationBarPageState extends State<NavigationBarPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Center(child: Text('Home')),
    Center(child: Text('Camera')),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: SizedBox(height: 62,
        child: StylishBottomBar(
          option: BubbleBarOptions(
            barStyle: BubbleBarStyle.horizontal, // keeps width stable
            bubbleFillStyle: BubbleFillStyle.fill,
            opacity: 0.15, // controls background intensity
          ),
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: [
            BottomBarItem(
              icon: SvgPicture.asset(
                'lib/assets/images/home.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
              selectedIcon: SvgPicture.asset(
                'lib/assets/images/home.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.blue,
                  BlendMode.srcIn,
                ),
              ),
              title: const Text('Home'),
              selectedColor: Colors.blue,
              unSelectedColor: Colors.grey,
              backgroundColor: Colors.blue,
            ),

            BottomBarItem(
              icon: SvgPicture.asset(
                'lib/assets/images/camera.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
              selectedIcon: SvgPicture.asset(
                'lib/assets/images/camera.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.blue,
                  BlendMode.srcIn,
                ),
              ),
              title: const Text('Camera'),
              selectedColor: Colors.blue,
              unSelectedColor: Colors.grey,
              backgroundColor: Colors.blue,
            ),

            BottomBarItem(
              icon: SvgPicture.asset(
                'lib/assets/images/profile.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
              selectedIcon: SvgPicture.asset(
                'lib/assets/images/profile.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.blue,
                  BlendMode.srcIn,
                ),
              ),
              title: const Text('Profile'),
              selectedColor: Colors.blue,
              unSelectedColor: Colors.grey,
              backgroundColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
