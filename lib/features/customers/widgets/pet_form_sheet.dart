import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../data/models/customer.dart';
import '../../../data/services/customer_service.dart';

/// Fallback breed lists when the API catalog is empty / not yet seeded.
const Map<String, List<String>> _fallbackBreedsBySpecies = {
  'dog': [
    'German Shepherd',
    'Beagle',
    'Indie',
    'Spitz',
    'Labrador Retriever',
    'Shih Tzu',
    'Lhasa Apso',
    'Golden Retriever',
    'Dachshund',
    'Pug',
    'Rottweiler',
    'Doberman',
  ],
  'cat': [
    'Persian',
    'Siamese',
    'Maine Coon',
    'British Shorthair',
    'Indie',
    'Bengal',
    'Ragdoll',
    'Sphynx',
    'Scottish Fold',
    'American Shorthair',
    'Other',
  ],
  'bird': [
    'Budgerigar',
    'Cockatiel',
    'Lovebird',
    'African Grey',
    'Macaw',
    'Canary',
    'Parrot',
    'Finch',
    'Other',
  ],
  'fish': [
    'Goldfish',
    'Betta',
    'Guppy',
    'Molly',
    'Angelfish',
    'Other',
  ],
  'rabbit': [
    'Dutch',
    'Holland Lop',
    'Netherland Dwarf',
    'Rex',
    'Angora',
    'Other',
  ],
  'other': ['Other'],
};

/// Shows Add/Edit Pet dialog (desktop/web) or bottom sheet (mobile).
/// Returns `true` when saved successfully.
Future<bool> showPetFormSheet(
  BuildContext context, {
  required int customerId,
  Pet? pet,
}) async {
  final bool? result;
  if (useCenteredFormDialog(context)) {
    result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => _PetFormDialog(customerId: customerId, pet: pet),
    );
  } else {
    result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PetFormBottomSheet(customerId: customerId, pet: pet),
    );
  }

  return result == true;
}

// ─── Shared form state / fields ─────────────────────────────────────────────

class _PetFormController {
  _PetFormController({Pet? pet}) {
    name = TextEditingController(text: pet?.name ?? '');
    weight = TextEditingController(
      text: pet?.weight != null ? _formatWeight(pet!.weight!) : '',
    );
    color = TextEditingController(text: pet?.color ?? '');
    final species = pet?.species?.trim();
    this.species = (species != null && species.isNotEmpty) ? species : null;
    breed = pet?.breed?.trim().isNotEmpty == true ? pet!.breed!.trim() : null;
    gender = (pet?.gender.isNotEmpty == true) ? pet!.gender : 'male';
    if (pet?.dob != null && pet!.dob!.isNotEmpty) {
      dob = DateTime.tryParse(pet.dob!);
    }
  }

  late final TextEditingController name;
  late final TextEditingController weight;
  late final TextEditingController color;
  String? species;
  String? breed;
  late String gender;
  DateTime? dob;

  List<PetSpecies> speciesOptions = const [];
  List<PetBreed> breedOptions = const [];
  bool loadingSpecies = false;
  bool loadingBreeds = false;
  String? speciesError;
  String? breedError;

  void dispose() {
    name.dispose();
    weight.dispose();
    color.dispose();
  }

  static String _formatWeight(double w) {
    return w == w.roundToDouble() ? w.toInt().toString() : w.toString();
  }

  Future<void> loadSpecies(CustomerService customers) async {
    loadingSpecies = true;
    speciesError = null;
    try {
      final items = await customers.listPetSpecies();
      speciesOptions = items;
      if (species != null &&
          species!.isNotEmpty &&
          !speciesOptions.any((s) => s.code == species)) {
        speciesOptions = [
          ...speciesOptions,
          PetSpecies(id: -1, code: species!, name: _titleCase(species!)),
        ];
      }
    } catch (e) {
      speciesError = '$e';
      speciesOptions = const [];
    } finally {
      loadingSpecies = false;
    }
  }

  Future<void> loadBreeds(
    CustomerService customers, {
    bool clearBreedIfMissing = true,
  }) async {
    final selected = species;
    if (selected == null || selected.isEmpty) {
      breedOptions = const [];
      breed = null;
      loadingBreeds = false;
      breedError = null;
      return;
    }

    loadingBreeds = true;
    breedError = null;
    try {
      final fallback = _fallbackBreedsBySpecies[selected];
      List<PetBreed> items;
      if (fallback != null) {
        items = [
          for (var i = 0; i < fallback.length; i++)
            PetBreed(id: -(i + 1), speciesId: 0, name: fallback[i]),
        ];
      } else {
        items = await customers.listPetBreeds(species: selected);
      }
      breedOptions = items;
      final currentBreed = breed;
      if (currentBreed != null && currentBreed.isNotEmpty) {
        final exists = breedOptions.any((b) => b.name == currentBreed);
        if (!exists) {
          if (clearBreedIfMissing) {
            breed = null;
          } else {
            breedOptions = [
              ...breedOptions,
              PetBreed(id: -1, speciesId: 0, name: currentBreed),
            ];
          }
        }
      }
    } catch (e) {
      final fallback = _fallbackBreedsBySpecies[selected] ?? const <String>[];
      if (fallback.isNotEmpty) {
        breedOptions = [
          for (var i = 0; i < fallback.length; i++)
            PetBreed(id: -(i + 1), speciesId: 0, name: fallback[i]),
        ];
        breedError = null;
      } else {
        breedError = '$e';
        breedOptions = const [];
      }
    } finally {
      loadingBreeds = false;
    }
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  Map<String, dynamic>? buildPayload(BuildContext context) {
    final trimmedName = name.text.trim();
    if (trimmedName.isEmpty) {
      AppMessenger.error(context, 'Pet name is required.');
      return null;
    }

    final weightText = weight.text.trim();
    double? weightValue;
    if (weightText.isNotEmpty) {
      weightValue = double.tryParse(weightText);
      if (weightValue == null || weightValue < 0) {
        AppMessenger.error(context, 'Enter a valid weight.');
        return null;
      }
    }

    return {
      'name': trimmedName,
      'species': species,
      'breed': breed?.trim().isEmpty == true ? null : breed?.trim(),
      'gender': gender,
      'dob': dob?.toIso8601String().substring(0, 10),
      'weight': weightValue,
      'color': color.text.trim().isEmpty ? null : color.text.trim(),
    };
  }
}

InputDecoration _fieldDecoration(String label, {Widget? suffixIcon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    suffixIcon: suffixIcon,
  );
}

String _formatDob(DateTime? date) {
  if (date == null) return '';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d-$m-${date.year}';
}

class _PetFormFields extends StatelessWidget {
  const _PetFormFields({
    required this.controller,
    required this.onChanged,
    required this.onSpeciesChanged,
    this.twoColumn = false,
  });

  final _PetFormController controller;
  final VoidCallback onChanged;
  final ValueChanged<String?> onSpeciesChanged;
  final bool twoColumn;

  Future<void> _pickDob(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.dob ?? DateTime(now.year - 1),
      firstDate: DateTime(1990),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Select date of birth',
    );
    if (picked != null) {
      controller.dob = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameField = TextField(
      controller: controller.name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration('Name *', hint: 'Pet name'),
    );

    final speciesValue = controller.speciesOptions.any((s) => s.code == controller.species)
        ? controller.species
        : null;

    final speciesField = AppDropdownButtonFormField<String>(
      value: speciesValue,
      hint: Text(
        controller.loadingSpecies ? 'Loading species...' : 'Select species',
      ),
      decoration: _fieldDecoration(
        'Species',
        hint: 'Select species',
        suffixIcon: controller.loadingSpecies
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        for (final s in controller.speciesOptions)
          DropdownMenuItem<String>(
            value: s.code,
            child: Text(s.name),
          ),
      ],
      onChanged: controller.loadingSpecies
          ? null
          : (v) {
              onSpeciesChanged(v);
            },
    );

    final breedValue = controller.breedOptions.any((b) => b.name == controller.breed)
        ? controller.breed
        : null;
    final breedEnabled =
        controller.species != null && !controller.loadingBreeds && !controller.loadingSpecies;

    final breedField = AppDropdownButtonFormField<String>(
      value: breedValue,
      hint: Text(
        controller.species == null
            ? 'Select species first'
            : controller.loadingBreeds
                ? 'Loading breeds...'
                : controller.breedOptions.isEmpty
                    ? 'No breeds for this species'
                    : 'Select breed',
      ),
      decoration: _fieldDecoration(
        'Breed',
        hint: 'Select breed',
        suffixIcon: controller.loadingBreeds
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        for (final b in controller.breedOptions)
          DropdownMenuItem<String>(
            value: b.name,
            child: Text(b.name),
          ),
      ],
      onChanged: breedEnabled
          ? (v) {
              controller.breed = v;
              onChanged();
            }
          : null,
    );

    final genderField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: Theme.of(context).inputDecorationTheme.labelStyle,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('Male')),
              ButtonSegment(value: 'female', label: Text('Female')),
              ButtonSegment(value: 'unknown', label: Text('Unknown')),
            ],
            selected: {controller.gender},
            onSelectionChanged: (s) {
              controller.gender = s.first;
              onChanged();
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.comfortable,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppTheme.textSecondary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary;
                }
                return Colors.white;
              }),
            ),
          ),
        ),
      ],
    );

    final dobText = _formatDob(controller.dob);
    final dobField = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickDob(context),
      child: InputDecorator(
        decoration: _fieldDecoration(
          'Date of birth',
          hint: 'dd-mm-yyyy',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.dob != null)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.dob = null;
                    onChanged();
                  },
                ),
              IconButton(
                tooltip: 'Pick date',
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                onPressed: () => _pickDob(context),
              ),
            ],
          ),
        ),
        child: Text(
          dobText.isEmpty ? 'dd-mm-yyyy' : dobText,
          style: TextStyle(
            color: dobText.isEmpty
                ? AppTheme.textSecondary
                : AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );

    final weightField = TextField(
      controller: controller.weight,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration('Weight (kg)', hint: '0.00'),
    );

    final colorField = TextField(
      controller: controller.color,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      decoration: _fieldDecoration('Color', hint: 'e.g. Brown'),
    );

    final lookupError = controller.speciesError ?? controller.breedError;
    final errorBanner = lookupError == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              lookupError,
              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
            ),
          );

    if (!twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          errorBanner,
          nameField,
          const SizedBox(height: 16),
          speciesField,
          const SizedBox(height: 16),
          breedField,
          const SizedBox(height: 16),
          genderField,
          const SizedBox(height: 16),
          dobField,
          const SizedBox(height: 16),
          weightField,
          const SizedBox(height: 16),
          colorField,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        errorBanner,
        nameField,
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: speciesField),
            const SizedBox(width: 16),
            Expanded(child: breedField),
          ],
        ),
        const SizedBox(height: 16),
        genderField,
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: dobField),
            const SizedBox(width: 16),
            Expanded(child: weightField),
          ],
        ),
        const SizedBox(height: 16),
        colorField,
      ],
    );
  }
}

class _PetFormHeader extends StatelessWidget {
  const _PetFormHeader({
    required this.isEdit,
    required this.onClose,
    this.showHandle = false,
  });

  final bool isEdit;
  final VoidCallback onClose;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHandle) ...[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20, showHandle ? 12 : 16, 8, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit Pet' : 'Add Pet',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isEdit
                          ? 'Update pet details'
                          : 'Register a pet for this customer',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }
}

class _PetFormFooter extends StatelessWidget {
  const _PetFormFooter({
    required this.isEdit,
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isEdit;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: saving ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? 'Update Pet' : 'Add Pet'),
            ),
          ),
        ],
      ),
    );
  }
}

mixin _PetFormLookupMixin<T extends StatefulWidget> on State<T> {
  late final _PetFormController form;

  Future<void> loadLookups({bool preserveBreed = true}) async {
    final customers = context.read<AppServices>().customers;
    setState(() => form.loadingSpecies = true);
    await form.loadSpecies(customers);
    if (!mounted) return;
    setState(() {});
    if (form.species != null) {
      await form.loadBreeds(
        customers,
        clearBreedIfMissing: !preserveBreed,
      );
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> onSpeciesChanged(String? code) async {
    form.species = code;
    form.breed = null;
    setState(() {});
    final customers = context.read<AppServices>().customers;
    await form.loadBreeds(customers, clearBreedIfMissing: true);
    if (!mounted) return;
    setState(() {});
  }
}

// ─── Desktop / web dialog ───────────────────────────────────────────────────

class _PetFormDialog extends StatefulWidget {
  const _PetFormDialog({required this.customerId, this.pet});

  final int customerId;
  final Pet? pet;

  @override
  State<_PetFormDialog> createState() => _PetFormDialogState();
}

class _PetFormDialogState extends State<_PetFormDialog>
    with _PetFormLookupMixin<_PetFormDialog> {
  bool _saving = false;

  bool get _isEdit => widget.pet != null;

  @override
  void initState() {
    super.initState();
    form = _PetFormController(pet: widget.pet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadLookups(preserveBreed: _isEdit);
    });
  }

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final payload = form.buildPayload(context);
    if (payload == null) return;

    setState(() => _saving = true);
    try {
      final customers = context.read<AppServices>().customers;
      if (_isEdit) {
        await customers.updatePet(widget.pet!.id, payload);
      } else {
        await customers.createPet({
          'customer_id': widget.customerId,
          ...payload,
        });
      }
      if (!mounted) return;
      AppMessenger.success(context, _isEdit ? 'Pet updated' : 'Pet added');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: maxHeight,
        ),
        child: SizedBox(
          width: 520,
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PetFormHeader(
                isEdit: _isEdit,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _PetFormFields(
                    controller: form,
                    twoColumn: true,
                    onChanged: () => setState(() {}),
                    onSpeciesChanged: onSpeciesChanged,
                  ),
                ),
              ),
              _PetFormFooter(
                isEdit: _isEdit,
                saving: _saving,
                onCancel: () => Navigator.pop(context),
                onSubmit: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile bottom sheet ────────────────────────────────────────────────────

class _PetFormBottomSheet extends StatefulWidget {
  const _PetFormBottomSheet({required this.customerId, this.pet});

  final int customerId;
  final Pet? pet;

  @override
  State<_PetFormBottomSheet> createState() => _PetFormBottomSheetState();
}

class _PetFormBottomSheetState extends State<_PetFormBottomSheet>
    with _PetFormLookupMixin<_PetFormBottomSheet> {
  bool _saving = false;

  bool get _isEdit => widget.pet != null;

  @override
  void initState() {
    super.initState();
    form = _PetFormController(pet: widget.pet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadLookups(preserveBreed: _isEdit);
    });
  }

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final payload = form.buildPayload(context);
    if (payload == null) return;

    setState(() => _saving = true);
    try {
      final customers = context.read<AppServices>().customers;
      if (_isEdit) {
        await customers.updatePet(widget.pet!.id, payload);
      } else {
        await customers.createPet({
          'customer_id': widget.customerId,
          ...payload,
        });
      }
      if (!mounted) return;
      AppMessenger.success(context, _isEdit ? 'Pet updated' : 'Pet added');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PetFormHeader(
                    isEdit: _isEdit,
                    showHandle: true,
                    onClose: () => Navigator.pop(context),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: _PetFormFields(
                        controller: form,
                        onChanged: () => setState(() {}),
                        onSpeciesChanged: onSpeciesChanged,
                      ),
                    ),
                  ),
                  _PetFormFooter(
                    isEdit: _isEdit,
                    saving: _saving,
                    onCancel: () => Navigator.pop(context),
                    onSubmit: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
