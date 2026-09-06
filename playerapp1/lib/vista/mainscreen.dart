import 'package:flutter/material.dart';
import 'package:playerapp1/vista/carpetas.dart';
import 'package:playerapp1/vista/config.dart';
import 'package:playerapp1/vista/favoritos.dart';
import 'package:playerapp1/vista/inicio.dart';
import 'package:playerapp1/vista/reproductor.dart';
import 'package:playerapp1/widgets/diseños/bottombar.dart';
import 'package:playerapp1/widgets/diseños/overlaydecarga.dart';
import 'package:playerapp1/widgets/diseños/pattern_background.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  bool importando = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      InicioScreen(
        onImportandoChanged: (valor) {
          if (mounted) {
            setState(() {
              importando = valor;
            });
          }
        },
      ),
      const CarpetasScreen(),
      PlayerScreen(
        onBack: () {
          setState(() {
            currentIndex = 0;
          });
        },
      ),
      const FavoritosScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PatternBackground(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            body: IndexedStack(
              index: currentIndex,
              children: _screens,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomBottomBar(
              currentIndex: currentIndex,
              onTap: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
            ),
          ),
          if (importando) const ImportandoOverlay(),
        ],
      ),
    );
  }
}