import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/usuario_model.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/chip_rol_activo.dart';

class ListaUsuariosScreen extends ConsumerStatefulWidget {
  const ListaUsuariosScreen({super.key});

  @override
  ConsumerState<ListaUsuariosScreen> createState() => _ListaUsuariosScreenState();
}

class _ListaUsuariosScreenState extends ConsumerState<ListaUsuariosScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UsuarioModel> _usuarios = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool? _filtroActivo;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final list = await repo.obtenerUsuarios(
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        activo: _filtroActivo,
      );
      setState(() {
        _usuarios = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.userPlus, size: 24),
            onPressed: () async {
              await context.push('/admin/usuarios/crear');
              _cargarUsuarios();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar usuario por nombre o correo...',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _cargarUsuarios();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _cargarUsuarios(),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text('Error: $_errorMessage'))
                      : _usuarios.isEmpty
                          ? Center(
                              child: Text(
                                'No se encontraron usuarios.',
                                style: CeosTheme.body(color: CeosColors.lightTextMuted),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _cargarUsuarios,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _usuarios.length,
                                itemBuilder: (context, index) {
                                  final u = _usuarios[index];
                                  final isInactive = !u.activo;

                                  return Opacity(
                                    // Inactivos visibles pero atenuados (HU-424)
                                    opacity: isInactive ? 0.5 : 1.0,
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: u.esSuperadmin
                                              ? CeosColors.roleSuperadmin.withOpacity(0.2)
                                              : CeosColors.areaOdontologia.withOpacity(0.15),
                                          child: Icon(
                                            u.esSuperadmin
                                                ? PhosphorIconsFill.crown
                                                : PhosphorIconsRegular.user,
                                            color: u.esSuperadmin
                                                ? CeosColors.roleSuperadmin
                                                : CeosColors.areaOdontologia,
                                            size: 20,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                u.username,
                                                style: CeosTheme.heading(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (isInactive)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: CeosColors.statusDangerLight,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'INACTIVO',
                                                  style: CeosTheme.dataMono(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: CeosColors.statusDanger,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(u.correoInterno, style: CeosTheme.body(fontSize: 12)),
                                            const SizedBox(height: 4),
                                            ChipRolActivo(rol: u.rolPrincipal, esSuperadmin: u.esSuperadmin),
                                          ],
                                        ),
                                        trailing: const Icon(PhosphorIconsRegular.caretRight, size: 16),
                                        onTap: () async {
                                          await context.push('/admin/usuarios/${u.id}');
                                          _cargarUsuarios();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
