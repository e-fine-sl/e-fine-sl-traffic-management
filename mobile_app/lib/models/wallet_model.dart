// lib/models/wallet_model.dart
// Dart models matching the wallet API response structure.
// ─────────────────────────────────────────────────────────

class WalletModel {
  final OwnerModel owner;
  final DrivingLicenseModel? drivingLicense;
  final List<VehicleModel> vehicles;
  final WalletSummaryModel summary;

  const WalletModel({
    required this.owner,
    this.drivingLicense,
    required this.vehicles,
    required this.summary,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        owner: OwnerModel.fromJson(json['owner'] as Map<String, dynamic>),
        drivingLicense: json['drivingLicense'] != null
            ? DrivingLicenseModel.fromJson(
                json['drivingLicense'] as Map<String, dynamic>)
            : null,
        vehicles: (json['vehicles'] as List<dynamic>?)
            ?.map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
            .toList() ?? [],
        summary: WalletSummaryModel.fromJson(
            json['summary'] as Map<String, dynamic>),
      );
}

class OwnerModel {
  final String nic;
  final String licenseNumber;
  final String fullName;
  final String? dateOfBirth;
  final String? address;
  final String? phoneNumber;
  final String? bloodGroup;
  final String? photo;

  const OwnerModel({
    required this.nic,
    required this.licenseNumber,
    required this.fullName,
    this.dateOfBirth,
    this.address,
    this.phoneNumber,
    this.bloodGroup,
    this.photo,
  });

  factory OwnerModel.fromJson(Map<String, dynamic> json) => OwnerModel(
        nic:           json['nic'] as String? ?? '',
        licenseNumber: json['licenseNumber'] as String? ?? '',
        fullName:      json['fullName'] as String? ?? '',
        dateOfBirth:   json['dateOfBirth'] as String?,
        address:       json['address'] as String?,
        phoneNumber:   json['phoneNumber'] as String?,
        bloodGroup:    json['bloodGroup'] as String?,
        photo:         json['photo'] as String?,
      );
}

class DrivingLicenseModel {
  final String licenseNo;
  final String? issueDate;
  final String? expiryDate;
  final List<String> vehicleClasses;
  final String? issuingAuthority;
  final String? restrictions;
  final String status;
  final String statusBadge;
  final String validityBadge;
  final int daysUntilExpiry;
  final bool isExpired;

  const DrivingLicenseModel({
    required this.licenseNo,
    this.issueDate,
    this.expiryDate,
    required this.vehicleClasses,
    this.issuingAuthority,
    this.restrictions,
    required this.status,
    required this.statusBadge,
    required this.validityBadge,
    required this.daysUntilExpiry,
    required this.isExpired,
  });

  factory DrivingLicenseModel.fromJson(Map<String, dynamic> json) =>
      DrivingLicenseModel(
        licenseNo:        json['licenseNo'] as String? ?? '',
        issueDate:        json['issueDate'] as String?,
        expiryDate:       json['expiryDate'] as String?,
        vehicleClasses:   List<String>.from(json['vehicleClasses'] as List? ?? []),
        issuingAuthority: json['issuingAuthority'] as String?,
        restrictions:     json['restrictions'] as String?,
        status:           json['status'] as String? ?? '',
        statusBadge:      json['statusBadge'] as String? ?? '',
        validityBadge:    json['validityBadge'] as String? ?? '',
        daysUntilExpiry:  json['daysUntilExpiry'] as int? ?? 0,
        isExpired:        json['isExpired'] as bool? ?? false,
      );
}

class VehicleModel {
  final String registrationNo;
  final String make;
  final String model;
  final int year;
  final String vehicleClass;
  final String? fuelType;
  final String? color;
  final int? seatingCapacity;
  final VehicleDocumentsModel documents;

  const VehicleModel({
    required this.registrationNo,
    required this.make,
    required this.model,
    required this.year,
    required this.vehicleClass,
    this.fuelType,
    this.color,
    this.seatingCapacity,
    required this.documents,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
        registrationNo: json['registrationNo'] as String? ?? '',
        make:           json['make'] as String? ?? '',
        model:          json['model'] as String? ?? '',
        year:           json['year'] as int? ?? 0,
        vehicleClass:   json['vehicleClass'] as String? ?? '',
        fuelType:       json['fuelType'] as String?,
        color:          json['color'] as String?,
        seatingCapacity:json['seatingCapacity'] as int?,
        documents:      VehicleDocumentsModel.fromJson(
            json['documents'] as Map<String, dynamic>),
      );
}

class VehicleDocumentsModel {
  final EmissionCertModel? emission;
  final InsuranceCertModel? insurance;
  final RevenueLicenseModel? revenueLicense;

  const VehicleDocumentsModel({
    this.emission,
    this.insurance,
    this.revenueLicense,
  });

  factory VehicleDocumentsModel.fromJson(Map<String, dynamic> json) =>
      VehicleDocumentsModel(
        emission: json['emission'] != null
            ? EmissionCertModel.fromJson(json['emission'] as Map<String, dynamic>)
            : null,
        insurance: json['insurance'] != null
            ? InsuranceCertModel.fromJson(
                json['insurance'] as Map<String, dynamic>)
            : null,
        revenueLicense: json['revenueLicense'] != null
            ? RevenueLicenseModel.fromJson(
                json['revenueLicense'] as Map<String, dynamic>)
            : null,
      );
}

class EmissionCertModel {
  final String serialNo;
  final String? systemNo;
  final String? dateOfIssue;
  final String? validTill;
  final String? testCentre;
  final String? inspector;
  final String? overallStatus;
  final String statusBadge;
  final String validityBadge;
  final int daysUntilExpiry;
  final bool isExpired;
  final String? issuingCompany;
  final String? referenceNo;
  final num? testFee;
  final EmissionReadingsModel? readings;
  final EmissionStandardsModel? standards;

  const EmissionCertModel({
    required this.serialNo,
    this.systemNo,
    this.dateOfIssue,
    this.validTill,
    this.testCentre,
    this.inspector,
    this.overallStatus,
    required this.statusBadge,
    required this.validityBadge,
    required this.daysUntilExpiry,
    required this.isExpired,
    this.issuingCompany,
    this.referenceNo,
    this.testFee,
    this.readings,
    this.standards,
  });

  factory EmissionCertModel.fromJson(Map<String, dynamic> json) =>
      EmissionCertModel(
        serialNo:       json['serialNo'] as String? ?? '',
        systemNo:       json['systemNo'] as String?,
        dateOfIssue:    json['dateOfIssue'] as String?,
        validTill:      json['validTill'] as String?,
        testCentre:     json['testCentre'] as String?,
        inspector:      json['inspector'] as String?,
        overallStatus:  json['overallStatus'] as String?,
        statusBadge:    json['statusBadge'] as String? ?? '',
        validityBadge:  json['validityBadge'] as String? ?? '',
        daysUntilExpiry:json['daysUntilExpiry'] as int? ?? 0,
        isExpired:      json['isExpired'] as bool? ?? false,
        issuingCompany: json['issuingCompany'] as String?,
        referenceNo:    json['referenceNo'] as String?,
        testFee:        json['testFee'] as num?,
        readings: json['readings'] != null
            ? EmissionReadingsModel.fromJson(
                json['readings'] as Map<String, dynamic>)
            : null,
        standards: json['standards'] != null
            ? EmissionStandardsModel.fromJson(
                json['standards'] as Map<String, dynamic>)
            : null,
      );
}

class EmissionReadingsModel {
  final EmissionReadingRow? idle;
  final EmissionReadingRow? rpm2500;
  final String? oilTemp;

  const EmissionReadingsModel({this.idle, this.rpm2500, this.oilTemp});

  factory EmissionReadingsModel.fromJson(Map<String, dynamic> json) =>
      EmissionReadingsModel(
        idle: json['idle'] != null
            ? EmissionReadingRow.fromJson(json['idle'] as Map<String, dynamic>)
            : null,
        rpm2500: json['rpm2500'] != null
            ? EmissionReadingRow.fromJson(
                json['rpm2500'] as Map<String, dynamic>)
            : null,
        oilTemp: json['oilTemp'] as String?,
      );
}

class EmissionReadingRow {
  final num? rpm;
  final num? hc;
  final num? co;
  final num? o2;
  final num? co2;

  const EmissionReadingRow({this.rpm, this.hc, this.co, this.o2, this.co2});

  factory EmissionReadingRow.fromJson(Map<String, dynamic> json) =>
      EmissionReadingRow(
        rpm: json['rpm'] as num?,
        hc:  json['hc'] as num?,
        co:  json['co'] as num?,
        o2:  json['o2'] as num?,
        co2: json['co2'] as num?,
      );
}

class EmissionStandardsModel {
  final num? hc;
  final num? co;

  const EmissionStandardsModel({this.hc, this.co});

  factory EmissionStandardsModel.fromJson(Map<String, dynamic> json) =>
      EmissionStandardsModel(
        hc: json['hc'] as num?,
        co: json['co'] as num?,
      );
}

class InsuranceCertModel {
  final String? certificateType;
  final String? policyNo;
  final String? insurer;
  final String? periodOfCoverStart;
  final String? periodOfCoverEnd;
  final String? coverageType;
  final String statusBadge;
  final String validityBadge;
  final int daysUntilExpiry;
  final bool isExpired;

  const InsuranceCertModel({
    this.certificateType,
    this.policyNo,
    this.insurer,
    this.periodOfCoverStart,
    this.periodOfCoverEnd,
    this.coverageType,
    required this.statusBadge,
    required this.validityBadge,
    required this.daysUntilExpiry,
    required this.isExpired,
  });

  factory InsuranceCertModel.fromJson(Map<String, dynamic> json) =>
      InsuranceCertModel(
        certificateType:    json['certificateType'] as String?,
        policyNo:           json['policyNo'] as String?,
        insurer:            json['insurer'] as String?,
        periodOfCoverStart: json['periodOfCoverStart'] as String?,
        periodOfCoverEnd:   json['periodOfCoverEnd'] as String?,
        coverageType:       json['coverageType'] as String?,
        statusBadge:        json['statusBadge'] as String? ?? '',
        validityBadge:      json['validityBadge'] as String? ?? '',
        daysUntilExpiry:    json['daysUntilExpiry'] as int? ?? 0,
        isExpired:          json['isExpired'] as bool? ?? false,
      );
}

class RevenueLicenseModel {
  final String? licenseNo;
  final String? issueDate;
  final String? expiryDate;
  final String? issuingAuthority;
  final num? annualFee;
  final String statusBadge;
  final String validityBadge;
  final int daysUntilExpiry;
  final bool isExpired;

  const RevenueLicenseModel({
    this.licenseNo,
    this.issueDate,
    this.expiryDate,
    this.issuingAuthority,
    this.annualFee,
    required this.statusBadge,
    required this.validityBadge,
    required this.daysUntilExpiry,
    required this.isExpired,
  });

  factory RevenueLicenseModel.fromJson(Map<String, dynamic> json) =>
      RevenueLicenseModel(
        licenseNo:        json['licenseNo'] as String?,
        issueDate:        json['issueDate'] as String?,
        expiryDate:       json['expiryDate'] as String?,
        issuingAuthority: json['issuingAuthority'] as String?,
        annualFee:        json['annualFee'] as num?,
        statusBadge:      json['statusBadge'] as String? ?? '',
        validityBadge:    json['validityBadge'] as String? ?? '',
        daysUntilExpiry:  json['daysUntilExpiry'] as int? ?? 0,
        isExpired:        json['isExpired'] as bool? ?? false,
      );
}

class WalletSummaryModel {
  final int totalVehicles;
  final int validDocuments;
  final int expiredDocuments;
  final int documentsNeedingRenewal;
  final String overallStatus;   // ALL_VALID | HAS_EXPIRED | HAS_ISSUES

  const WalletSummaryModel({
    required this.totalVehicles,
    required this.validDocuments,
    required this.expiredDocuments,
    required this.documentsNeedingRenewal,
    required this.overallStatus,
  });

  factory WalletSummaryModel.fromJson(Map<String, dynamic> json) =>
      WalletSummaryModel(
        totalVehicles:           json['totalVehicles'] as int? ?? 0,
        validDocuments:          json['validDocuments'] as int? ?? 0,
        expiredDocuments:        json['expiredDocuments'] as int? ?? 0,
        documentsNeedingRenewal: json['documentsNeedingRenewal'] as int? ?? 0,
        overallStatus:           json['overallStatus'] as String? ?? '',
      );
}
