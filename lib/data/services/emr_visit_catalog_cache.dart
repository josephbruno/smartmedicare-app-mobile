import '../models/emr.dart';
import '../models/investigation_under.dart';
import '../models/prescription_under.dart';
import '../models/product.dart';
import '../models/treatment_under.dart';
import 'emr_master_data_service.dart';
import 'emr_service.dart';

/// In-memory visit-form catalogs for the current app session.
///
/// First visit still hits the API; later opens reuse this until [ttl] expires.
class EmrVisitCatalogCache {
  EmrVisitCatalogCache._();

  static const ttl = Duration(minutes: 10);

  static DateTime? _loadedAt;
  static int? shopId;
  static Future<void>? _inFlight;

  static List<DoctorLite> doctors = const [];
  static List<String> complaints = const [];
  static List<EmrTemplateItem> reviewIntervals = const [];
  static List<String> investigations = const [];
  static List<TreatmentSuggestion> treatments = const [];
  static List<MedicineSuggestion> medicines = const [];
  static List<TreatmentUnderCategoryItem> treatmentUnderCategories = const [];
  static List<PrescriptionUnderCategoryItem> prescriptionUnderCategories =
      const [];
  static List<InvestigationUnderCategoryItem> investigationUnderCategories =
      const [];
  static final Map<String, List<Product>> treatmentUnderMapped = {};
  static final Map<String, List<Product>> prescriptionUnderMapped = {};
  static final Map<String, List<Product>> investigationUnderMapped = {};
  static final Map<String, List<VaccinationTemplate>> vaccinationsBySpecies = {};

  static bool get isFresh =>
      _loadedAt != null && DateTime.now().difference(_loadedAt!) < ttl;

  static bool get hasSuggestions =>
      doctors.isNotEmpty || complaints.isNotEmpty;

  static void bindShop(int? id) {
    if (id == null) return;
    if (shopId != null && shopId != id) {
      clear();
    }
    shopId = id;
  }

  static void touch() => _loadedAt = DateTime.now();

  static void saveDoctors(List<DoctorLite> value) {
    doctors = List<DoctorLite>.of(value);
    touch();
  }

  static void saveComplaints(List<String> value) {
    complaints = List<String>.of(value);
    touch();
  }

  static void saveReviewIntervals(List<EmrTemplateItem> value) {
    reviewIntervals = List<EmrTemplateItem>.of(value);
    touch();
  }

  static void saveInvestigations(List<String> value) {
    investigations = List<String>.of(value);
    touch();
  }

  static void saveTreatments(List<TreatmentSuggestion> value) {
    treatments = List<TreatmentSuggestion>.of(value);
    touch();
  }

  static void saveMedicines(List<MedicineSuggestion> value) {
    medicines = List<MedicineSuggestion>.of(value);
    touch();
  }

  static void saveTreatmentUnderCategories(
    List<TreatmentUnderCategoryItem> value,
  ) {
    treatmentUnderCategories = List<TreatmentUnderCategoryItem>.of(value);
    touch();
  }

  static void savePrescriptionUnderCategories(
    List<PrescriptionUnderCategoryItem> value,
  ) {
    prescriptionUnderCategories =
        List<PrescriptionUnderCategoryItem>.of(value);
    touch();
  }

  static void saveInvestigationUnderCategories(
    List<InvestigationUnderCategoryItem> value,
  ) {
    investigationUnderCategories =
        List<InvestigationUnderCategoryItem>.of(value);
    touch();
  }

  static void saveMapped({
    required bool prescription,
    required String category,
    required List<Product> products,
  }) {
    final copy = List<Product>.of(products);
    if (prescription) {
      prescriptionUnderMapped[category] = copy;
    } else {
      treatmentUnderMapped[category] = copy;
    }
    touch();
  }

  static void saveInvestigationMapped({
    required String category,
    required List<Product> products,
  }) {
    investigationUnderMapped[category] = List<Product>.of(products);
    touch();
  }

  static List<Product>? investigationMapped(String category) {
    final list = investigationUnderMapped[category];
    return list == null ? null : List<Product>.of(list);
  }

  static List<Product>? mapped({
    required bool prescription,
    required String category,
  }) {
    final list = prescription
        ? prescriptionUnderMapped[category]
        : treatmentUnderMapped[category];
    return list == null ? null : List<Product>.of(list);
  }

  static void saveVaccinations(String species, List<VaccinationTemplate> value) {
    vaccinationsBySpecies[species] = List<VaccinationTemplate>.of(value);
    touch();
  }

  static List<VaccinationTemplate>? vaccinations(String species) {
    final list = vaccinationsBySpecies[species];
    return list == null ? null : List<VaccinationTemplate>.of(list);
  }

  /// Warm catalogs after login so the visit form opens without waiting.
  static Future<void> prefetch({
    required EmrService emr,
    required EmrMasterDataService master,
    int? shopId,
  }) {
    bindShop(shopId);
    if (isFresh && hasSuggestions && treatmentUnderMapped.isNotEmpty) {
      return Future.value();
    }
    return _inFlight ??= _prefetchNow(emr: emr, master: master)
        .whenComplete(() => _inFlight = null);
  }

  static Future<void> _prefetchNow({
    required EmrService emr,
    required EmrMasterDataService master,
  }) async {
    try {
      await Future.wait([
        emr.listDoctors().then(saveDoctors),
        emr.getComplaints().then(saveComplaints),
        emr.getReviewIntervals().then(saveReviewIntervals),
        emr.getInvestigations().then(saveInvestigations),
        emr.getTreatmentSuggestions().then(saveTreatments),
        emr.getMedicineSuggestions().then(saveMedicines),
        _prefetchMapped(master),
      ]);
    } catch (_) {}
  }

  static Future<void> _prefetchMapped(EmrMasterDataService master) async {
    try {
      late List<TreatmentUnderCategoryItem> treatmentCats;
      late List<PrescriptionUnderCategoryItem> prescriptionCats;
      late List<InvestigationUnderCategoryItem> investigationCats;
      await Future.wait([
        master.listTreatmentUnderCategories().then((v) => treatmentCats = v),
        master.listPrescriptionUnderCategories().then((v) => prescriptionCats = v),
        master
            .listInvestigationUnderCategories()
            .then((v) => investigationCats = v),
      ]);
      saveTreatmentUnderCategories(treatmentCats);
      savePrescriptionUnderCategories(prescriptionCats);
      saveInvestigationUnderCategories(investigationCats);

      final firstTreatment =
          treatmentCats.isNotEmpty ? treatmentCats.first.slug : null;
      final firstPrescription =
          prescriptionCats.isNotEmpty ? prescriptionCats.first.slug : null;
      final firstInvestigation =
          investigationCats.isNotEmpty ? investigationCats.first.slug : null;

      await Future.wait([
        if (firstTreatment != null)
          master
              .listTreatmentUnderProducts(
                category: firstTreatment,
                isActive: true,
              )
              .then(
                (list) => saveMapped(
                  prescription: false,
                  category: firstTreatment,
                  products: list,
                ),
              ),
        if (firstPrescription != null)
          master
              .listPrescriptionUnderProducts(
                category: firstPrescription,
                isActive: true,
              )
              .then(
                (list) => saveMapped(
                  prescription: true,
                  category: firstPrescription,
                  products: list,
                ),
              ),
        if (firstInvestigation != null)
          master
              .listInvestigationUnderProducts(
                category: firstInvestigation,
                isActive: true,
              )
              .then(
                (list) => saveInvestigationMapped(
                  category: firstInvestigation,
                  products: list,
                ),
              ),
      ]);
    } catch (_) {}
  }

  static void clear() {
    _loadedAt = null;
    shopId = null;
    _inFlight = null;
    doctors = const [];
    complaints = const [];
    reviewIntervals = const [];
    investigations = const [];
    treatments = const [];
    medicines = const [];
    treatmentUnderCategories = const [];
    prescriptionUnderCategories = const [];
    investigationUnderCategories = const [];
    treatmentUnderMapped.clear();
    prescriptionUnderMapped.clear();
    investigationUnderMapped.clear();
    vaccinationsBySpecies.clear();
  }
}
