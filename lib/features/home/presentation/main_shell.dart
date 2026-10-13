import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../busqueda/presentation/busqueda_screen.dart';
import '../../catalogo/presentation/mis_publicaciones_screen.dart';
import '../../chat/models/conversacion.dart';
import '../../chat/presentation/conversaciones_screen.dart';
import '../../chat/providers/chat_providers.dart';
import '../../perfil/presentation/perfil_screen.dart';

/// Shell con navegación por pestañas: antes "Inicio" mezclaba búsqueda,
/// accesos rápidos y el panel de la vendedora en una sola pantalla larga.
/// Separar en pestañas (Inicio = comprar, Mis ventas = vender, Mensajes,
/// Perfil) deja cada una con un solo propósito.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _indiceMisVentas = 1;
  static const _indicePerfil = 3;

  int _indice = 0;
  final _misPublicacionesKey = GlobalKey<MisPublicacionesScreenState>();

  void _cambiarTab(int indice) {
    setState(() => _indice = indice);
    // Al volver a "Mis ventas" puede haber cambiado algo en otra pestaña
    // (se verificó la identidad, se conectó Mercado Pago, se vendió algo
    // desde el chat) — con IndexedStack no hay un ciclo de vida de
    // "reaparecí" que dispare esto solo, así que se refresca a mano cada
    // vez que se entra a esta pestaña.
    if (indice == _indiceMisVentas) {
      _misPublicacionesKey.currentState?.recargarEstado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          const BusquedaScreen(),
          MisPublicacionesScreen(
            key: _misPublicacionesKey,
            onIrAPerfil: () => _cambiarTab(_indicePerfil),
          ),
          const ConversacionesScreen(),
          const PerfilScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _cambiarTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Mis publicaciones',
          ),
          NavigationDestination(
            icon: usuario == null
                ? const Icon(Icons.chat_bubble_outline_rounded)
                : StreamBuilder<List<Conversacion>>(
                    stream: ref
                        .read(chatRepositoryProvider)
                        .misConversaciones(usuario.uid),
                    builder: (context, snapshot) {
                      final sinLeer = (snapshot.data ?? const [])
                          .where((c) => c.noLeidoPor(usuario.uid))
                          .length;
                      return Badge(
                        isLabelVisible: sinLeer > 0,
                        label: Text(sinLeer > 9 ? '9+' : '$sinLeer'),
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      );
                    },
                  ),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: 'Mensajes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
