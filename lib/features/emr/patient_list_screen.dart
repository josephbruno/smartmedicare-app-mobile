import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/emr.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final search = _search.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search patients by name or owner...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: AppPaginatedTable<PetSearchResult>(
              key: ValueKey(search),
              emptyMessage: 'No patients found.',
              loadPage: ({required page, required perPage}) =>
                  services.emr.listPetsPaginated(
                    page: page,
                    perPage: perPage,
                    search: search.length >= 2 ? search : null,
                  ),
              onRowTap: (pet) => context.push('/emr/pets/${pet.id}/timeline'),
              columns: const [
                TableColumnDef(label: 'Pet', flex: 1.2, cellBuilder: _petCell),
                TableColumnDef(label: 'Species', flex: 1, cellBuilder: _speciesCell),
                TableColumnDef(label: 'Breed', flex: 1.2, cellBuilder: _breedCell),
                TableColumnDef(label: 'Owner', flex: 1.5, cellBuilder: _ownerCell),
                TableColumnDef(label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _petCell(BuildContext context, PetSearchResult p) => Text(
        p.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _speciesCell(BuildContext context, PetSearchResult p) =>
      Text(p.species ?? '—');

  static Widget _breedCell(BuildContext context, PetSearchResult p) =>
      Text(p.breed ?? '—');

  static Widget _ownerCell(BuildContext context, PetSearchResult p) =>
      Text(p.customerName ?? '—');

  static Widget _phoneCell(BuildContext context, PetSearchResult p) =>
      Text(p.customerPhone ?? '—', style: const TextStyle(color: AppTheme.textSecondary));
}
