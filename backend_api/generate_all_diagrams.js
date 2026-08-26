const fs = require('fs');
const path = require('path');
const https = require('https');

const outputDir = path.resolve(__dirname, '..', 'docs', 'diagrams');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// 15 Comprehensive Thesis-Grade Architectural Diagrams
const diagrams = [
  {
    id: '01_high_level_system_architecture',
    title: 'High-Level 3-Tier Enterprise System Architecture',
    code: `graph TD
    subgraph ClientLayer ["Client Layer (Presentation Layer)"]
        FlutterDriver["Flutter Mobile App (Driver Module)"]
        FlutterPolice["Flutter Mobile App (Police Officer Module)"]
        WebAdmin["Next.js 14 React Admin Portal"]
    end

    subgraph GatewayLayer ["Security, Gateway & Middleware Layer"]
        CorsMiddleware["CORS & Request Sanitization"]
        JWTMiddleware["JWT Authentication & RBAC Filter"]
        CryptoService["RSA / AES Crypto & Payload Signatures"]
    end

    subgraph ApiLayer ["Backend Application & Service Layer (Node.js + Express)"]
        AuthCtrl["Authentication & KYC Controller"]
        FineCtrl["Fine Issuance & Citations Controller"]
        DriverCtrl["Driver Dossier & Demerit Controller"]
        AccidentCtrl["Accident & Hazard Incident Controller"]
        SOSCtrl["Geospatial Emergency SOS Engine"]
        AdminCtrl["Admin Suite & System Config Controller"]
        PaymentCtrl["PayHere Payment Gateway Controller"]
    end

    subgraph AsyncLayer ["Asynchronous Notification & Scheduling Engines"]
        CronJob["Node-Cron Demerit Recovery Engine"]
        FCMService["Firebase Admin SDK (FCM High-Priority Push)"]
        EmailService["Nodemailer & SendGrid HTTPS Dispatcher"]
    end

    subgraph DataLayer ["Data & Persistence Layer"]
        MongoDB[(MongoDB Primary Replica Set)]
        Geo2DSphere["MongoDB 2dsphere Spatial Geospatial Index"]
    end

    FlutterDriver -->|HTTPS / REST API| CorsMiddleware
    FlutterPolice -->|HTTPS / REST API| CorsMiddleware
    WebAdmin -->|HTTPS / REST API| CorsMiddleware

    CorsMiddleware --> JWTMiddleware
    JWTMiddleware --> CryptoService

    CryptoService --> AuthCtrl
    CryptoService --> FineCtrl
    CryptoService --> DriverCtrl
    CryptoService --> AccidentCtrl
    CryptoService --> SOSCtrl
    CryptoService --> AdminCtrl
    CryptoService --> PaymentCtrl

    AuthCtrl --> MongoDB
    FineCtrl --> MongoDB
    DriverCtrl --> MongoDB
    AccidentCtrl --> MongoDB
    SOSCtrl --> Geo2DSphere
    AdminCtrl --> MongoDB
    PaymentCtrl --> MongoDB

    FineCtrl --> FCMService
    FineCtrl --> EmailService
    DriverCtrl --> FCMService
    DriverCtrl --> EmailService
    SOSCtrl --> FCMService
    CronJob -->|Monthly Auto-Recovery| DriverCtrl`
  },
  {
    id: '02_system_use_case_diagram',
    title: 'System Use Case Diagram with 4 Stakeholder Actors & Automated Engine',
    code: `flowchart LR
    subgraph Boundary ["e-Fine SL Core System Boundary"]
        direction TB
        UC01(["UC-01: Register & Perform KYC Liveness Verification"])
        UC02(["UC-02: Authenticate & Manage Session"])
        UC03(["UC-03: Scan Driving License (ML Kit OCR)"])
        UC04(["UC-04: Issue Traffic Fine & Deduct Demerits"])
        UC05(["UC-05: Settle Fine via PayHere Gateway Sandbox"])
        UC06(["UC-06: Broadcast Emergency SOS Alert (10km Radius)"])
        UC07(["UC-07: Report Road Accident with Geotag & Photos"])
        UC08(["UC-08: Verify Officer Registration via OTP Secret"])
        UC09(["UC-09: Auto-Recover Good-Behavior Demerit Points"])
        UC10(["UC-10: Manage Driver Dossier & Suspend License"])
        UC11(["UC-11: Configure System Rules & Trigger Manual Recovery"])
    end

    CitizenDriver["Citizen Driver"]
    TrafficOfficer["Traffic Police Officer"]
    StationOIC["Station OIC"]
    SystemAdmin["System Super Admin"]
    CronEngine["Automated System Cron"]

    CitizenDriver --> UC01
    CitizenDriver --> UC02
    CitizenDriver --> UC05
    CitizenDriver --> UC06
    CitizenDriver --> UC07

    TrafficOfficer --> UC02
    TrafficOfficer --> UC03
    TrafficOfficer --> UC04

    StationOIC --> UC08

    SystemAdmin --> UC02
    SystemAdmin --> UC10
    SystemAdmin --> UC11

    CronEngine --> UC09

    UC04 -. "<<include>>" .-> UC03
    UC05 -. "<<extends>>" .-> UC04
    UC06 -. "<<include>>" .-> UC02
    UC10 -. "<<include>>" .-> UC02
    UC11 -. "<<include>>" .-> UC02`
  },
  {
    id: '03_unified_system_class_diagram',
    title: 'Unified System Class Diagram with Complete Domain Entities & Operations',
    code: `classDiagram
    direction LR

    class Driver {
        +ObjectId _id
        +String nic
        +String licenseNumber
        +String name
        +String email
        +String phone
        +Number demeritPoints
        +Number ratingScore
        +String licenseStatus
        +String demeritLevel
        +Boolean kycVerified
        +String fcmToken
        +Date lastOffenseDate
        +Date suspendedAt
        +String suspensionReason
        +register(driverDto)
        +verifyKYCLiveness(selfie, license)
        +updateProfile(profileDto)
        +deductDemerits(points)
        +restoreDemerits(points)
        +suspendLicense(reason)
        +activateLicense()
    }

    class Police {
        +ObjectId _id
        +String badgeNumber
        +String name
        +String email
        +String nic
        +String phone
        +String policeStation
        +String position
        +String role
        +GeoPoint location
        +String appState
        +Boolean isActive
        +String fcmToken
        +updateLocation(coords)
        +setDutyAppState(state)
        +issueSpotFine(fineDto)
    }

    class Admin {
        +ObjectId _id
        +String name
        +String email
        +String role
        +Boolean isTwoFactorEnabled
        +Date lastLoginAt
        +authenticate(credentials)
        +verify2FA(totpToken)
        +manageDriverDossier(driverId, action)
        +adjustDemerits(driverId, delta)
        +updateSystemConfig(configDto)
        +triggerManualRecovery()
    }

    class AdminSession {
        +ObjectId _id
        +ObjectId userId
        +String sessionToken
        +String refreshTokenHash
        +String ipAddress
        +Date expiresAt
        +Boolean isValid
        +createSession()
        +invalidateSession()
        +validateSession()
    }

    class IssuedFine {
        +ObjectId _id
        +String licenseNumber
        +String vehicleNumber
        +ObjectId offenseId
        +String offenseName
        +Number amount
        +String place
        +String policeStation
        +String policeOfficerId
        +String status
        +String paymentId
        +Date paidAt
        +Number demeritPoints
        +Date date
        +String paymentNotes
        +createFine(fineDto)
        +markPaid(paymentId, channel)
        +disputeFine(reason)
        +refundFine()
    }

    class Offense {
        +ObjectId _id
        +String offenseName
        +Number amount
        +String description
        +String sectionOfAct
        +Number demeritValue
        +String category
        +createOffense(offenseDto)
        +updateOffense(id, offenseDto)
    }

    class AccidentReport {
        +ObjectId _id
        +String driverLicense
        +String accidentType
        +String severity
        +GeoPoint location
        +String placeDescription
        +String province
        +String district
        +String policeStation
        +String status
        +List images
        +List statusHistory
        +createReport(reportDto)
        +acknowledgeReport(officerId)
        +resolveReport(notes)
    }

    class Station {
        +ObjectId _id
        +String stationCode
        +String name
        +String district
        +String province
        +String officialEmail
        +String phoneNumber
        +GeoPoint location
        +findNearestStation(coords)
        +listActiveOfficers()
    }

    class SystemConfig {
        +ObjectId _id
        +Number accidentNotificationRadiusKm
        +Number emergencySosRadiusKm
        +Number officerLogoutGracePeriodMinutes
        +Number defaultDemeritPoints
        +Number monthlyRecoveryPoints
        +Number cleanRecordDays
        +Number recoveryPeriodMonths
        +Boolean recoveryEnabled
        +Date lastRecoveryRunAt
        +Number finePaymentGraceDays
        +Boolean enableOnlinePayments
        +Number sessionTimeoutMinutes
        +updateConfig(configDto)
        +triggerManualRecovery()
    }

    class GeoPoint {
        +String type
        +List coordinates
    }

    class FCMService {
        +sendToToken(fcmToken, payload)
        +broadcastSOS(tokens, payload)
        +sendTrafficAlert(token, details)
    }

    class EmailService {
        +sendFineIssuedEmail(driver, fine, offense, points, remaining)
        +sendLicenseStatusEmail(driver, status, reason)
        +sendDemeritAdjustmentEmail(driver, delta, total, reason)
        +sendProfileUpdatedEmail(driver, fields)
    }

    class DemeritRecoveryCronJob {
        +executeMonthlyRecoveryJob()
        +evaluateDriverEligibility(driver, rules)
    }

    Driver "1" -- "0..*" IssuedFine : incurs
    Police "1" -- "0..*" IssuedFine : issues
    Offense "1" -- "0..*" IssuedFine : categorizes
    Driver "1" -- "0..*" AccidentReport : reports
    Station "1" -- "0..*" Police : assigns
    Station "1" -- "0..*" AccidentReport : receives
    Admin "1" -- "0..*" AdminSession : creates
    Admin "1" -- "1" SystemConfig : manages
    Police *-- "1" GeoPoint : contains
    Station *-- "1" GeoPoint : contains
    AccidentReport *-- "1" GeoPoint : contains
    IssuedFine ..> FCMService : triggers
    IssuedFine ..> EmailService : triggers
    DemeritRecoveryCronJob ..> SystemConfig : reads rules
    DemeritRecoveryCronJob ..> Driver : restores points`
  },
  {
    id: '04_sequence_kyc_ocr_liveness',
    title: 'Sequence 1: Driver KYC Facial Liveness & License OCR Verification',
    code: `sequenceDiagram
    autonumber
    actor Driver as Driver Mobile App
    participant FlutterOCR as ML Kit OCR Engine
    participant FlutterFace as ML Kit Liveness Tracker
    participant Backend as Node.js Backend API
    participant DB as MongoDB Cluster

    Driver->>FlutterOCR: Capture License Front & Back Images
    FlutterOCR->>FlutterOCR: Extract License Text (Issue Date 4a, Expiry 11, Class)
    FlutterOCR-->>Driver: Extracted License Metadata
    
    Driver->>FlutterFace: Initiate Face Liveness Camera Stream
    FlutterFace->>FlutterFace: Track Facial Landmarks (Blink Prob > 0.7, Smile > 0.6)
    FlutterFace-->>Driver: Liveness Verification Challenge Passed

    Driver->>Backend: POST /api/kyc/verify-liveness (Selfie Base64 + License Data)
    Backend->>DB: Find Driver by License & Update kycVerified = true
    DB-->>Backend: Driver Document Persisted
    Backend-->>Driver: 200 OK (KYC Verified & Initial Demerits Active)`
  },
  {
    id: '05_sequence_fine_issuance_demerits',
    title: 'Sequence 2: Roadside Fine Issuance, Demerit Deduction & Dual Alert Dispatch',
    code: `sequenceDiagram
    autonumber
    actor Officer as Traffic Police Officer
    participant App as Police Mobile App
    participant API as Node.js Backend API
    participant DB as MongoDB Cluster
    participant FCM as Firebase Cloud Messaging
    participant Email as SendGrid / Nodemailer Gateway
    actor Driver as Citizen Driver

    Officer->>App: Input/Scan Driver License, Vehicle Plate & Select Offense
    App->>API: POST /api/fines/issue (License, Vehicle, OffenseId, Location)
    API->>DB: Query Driver by License & Query Offense Details
    DB-->>API: Driver (Demerits: 24) & Offense (DemeritValue: 2, Amount: LKR 2000)

    API->>API: Calculate New Demerits = 24 - 2 = 22 pts
    API->>API: Calculate New Rating Score = (22 / 24) * 5.0 = 4.6 Stars
    
    API->>DB: Create IssuedFine (status: UNPAID, demeritPoints: 2)
    API->>DB: Update Driver (demeritPoints: 22, ratingScore: 4.6, lastOffenseDate: Now)
    DB-->>API: Transaction Committed

    par Dual Notification Dispatch
        API->>FCM: sendToToken(driver.fcmToken, { title: 'Traffic Fine Issued', channelId: 'traffic_alerts' })
        FCM->>Driver: Push Banner Alert on Phone (-2 Demerit pts)
    and
        API->>Email: sendFineIssuedEmail(driver, fine, offense, demeritDeduction: 2, remaining: 22)
        Email->>Driver: Official Traffic Citation Notice Email Delivered
    end

    API-->>App: 201 Created (Fine Issued Successfully)`
  },
  {
    id: '06_sequence_payhere_settlement',
    title: 'Sequence 3: Fine Payment Settlement via PayHere Gateway & Webhook Signature Verification',
    code: `sequenceDiagram
    autonumber
    actor Driver as Citizen Driver
    participant App as Driver Mobile App
    participant API as Node.js Backend API
    participant PayHere as PayHere Payment Gateway
    participant DB as MongoDB Cluster

    Driver->>App: Select Unpaid Citation & Tap "Pay Fine"
    App->>API: POST /api/payment/checkout (Fine ID)
    API->>API: Generate MD5 Hash Signature (Merchant ID, Order ID, Amount, Currency, Secret)
    API-->>App: Return Checkout Parameters + MD5 Signature Hash

    App->>PayHere: Launch PayHere Web SDK / Webview Checkout
    Driver->>PayHere: Enter Card/Wallet Details & Submit
    PayHere->>PayHere: Authorize & Process Transaction

    PayHere->>API: POST /api/payment/notify (Webhook Payload + MD5 Sig)
    API->>API: Re-calculate MD5 Hash & Verify Authenticity
    alt Signature Valid & Status == 2 (SUCCESS)
        API->>DB: Update IssuedFine (status: 'PAID', paidAt: Date, paymentId: PayHereID)
        DB-->>API: Document Updated
        API-->>PayHere: HTTP 200 OK ACK
    else Signature Invalid / Hash Mismatch
        API-->>PayHere: HTTP 400 Bad Request (Fraud Attempt Dropped)
    end

    PayHere-->>App: Redirect Payment Success Screen`
  },
  {
    id: '07_sequence_emergency_sos_dispatch',
    title: 'Sequence 4: Geospatial Emergency SOS Alert Broadcast (10km Spatial Query)',
    code: `sequenceDiagram
    autonumber
    actor Driver as Citizen Driver
    participant App as Driver Mobile App
    participant API as Node.js Backend API
    participant DB as MongoDB (2dsphere Index)
    participant FCM as Firebase Cloud Messaging
    actor Officers as Nearby Active Police Officers

    Driver->>App: Tap "EMERGENCY SOS" Button
    App->>API: POST /api/sos/trigger (Latitude, Longitude, Driver Info)
    
    API->>DB: Query Police Collection with $near Spatial Operator
    Note over API,DB: $near: [lng, lat], $maxDistance: 5,000m, appState: FOREGROUND/BACKGROUND
    DB-->>API: Return Array of Active Officer FCM Tokens within 5km

    API->>FCM: Broadcast High-Priority SOS Payload (channelId: 'sos_alerts', siren sound)
    FCM->>Officers: Trigger Emergency Audio Siren & Map Coordinate Overlay
    API-->>App: 200 OK (SOS Dispatched to N Nearby Officers)`
  },
  {
    id: '08_sequence_admin_driver_management_suspension',
    title: 'Sequence 5: Administrative Driver Dossier Management & License Suspension',
    code: `sequenceDiagram
    autonumber
    actor Admin as Super Admin / Admin Officer
    participant Portal as Next.js Admin Portal
    participant API as Node.js Backend API
    participant DB as MongoDB Cluster
    participant FCM as Firebase Cloud Messaging
    participant Email as SendGrid / Nodemailer Gateway
    actor Driver as Citizen Driver

    Admin->>Portal: Search Driver (License: B5395114) & Open Dossier
    Portal->>API: GET /api/admin/drivers/:id
    API->>DB: Query Driver Record & Citation History
    DB-->>API: Driver Profile (demeritPoints: 22, status: ACTIVE)
    API-->>Portal: Render Full Dossier & Demerit Scorecard

    Admin->>Portal: Click "Suspend License", Input Reason & Confirm
    Portal->>API: PUT /api/admin/drivers/:id/suspend { reason: "Dangerous Driving Sec 140" }
    
    API->>DB: Update Driver (licenseStatus: 'SUSPENDED', suspendedAt: Now, suspensionReason)
    DB-->>API: Driver Document Updated

    par Dual Notification Dispatch
        API->>FCM: sendToToken(driver.fcmToken, { title: 'DRIVING LICENSE SUSPENDED', reason })
        FCM->>Driver: High-Priority Alert Banner on Mobile Phone
    and
        API->>Email: sendLicenseStatusEmail(driver, 'SUSPENDED', reason)
        Email->>Driver: Official Police Legal Suspension Notice HTML Email
    end

    API-->>Portal: 200 OK (Driver Suspended Successfully)
    Portal-->>Admin: Show Success Toast & Refresh Badge to SUSPENDED`
  },
  {
    id: '09_sequence_monthly_demerit_recovery_cron',
    title: 'Sequence 6: Automated Monthly Demerit Point Recovery Cron Job',
    code: `sequenceDiagram
    autonumber
    participant Cron as Node-Cron Engine (0 0 1 * *)
    participant Config as SystemConfig in DB
    participant DB as MongoDB Cluster
    participant FCM as Firebase Cloud Messaging
    participant Email as SendGrid / Nodemailer Gateway
    actor Driver as Clean-Record Driver

    Cron->>Config: Fetch SystemConfig (recoveryEnabled, monthlyRecoveryPoints: 2, cleanDays: 30)
    Config-->>Cron: Active Rules Configuration

    Cron->>DB: Query Active Drivers with demerits < 24 & lastOffenseDate older than cleanDays
    DB-->>Cron: List of Eligible Clean Drivers

    loop For Each Eligible Driver
        Cron->>DB: Update demeritPoints = min(24, current + 2), recalculate ratingScore
        par Notify Driver
            Cron->>FCM: sendToToken (Good Driver Demerit Recovery +2 pts)
            FCM->>Driver: Push Notification on Phone
        and
            Cron->>Email: sendDemeritAdjustmentEmail (Good Driver Conduct +2 pts)
            Email->>Driver: Demerit Reinstatement Notice Email
        end
    end

    Cron->>Config: Update lastRecoveryRunAt = Now`
  },
  {
    id: '10_activity_kyc_verification_flow',
    title: 'Activity 1: Driver Signup & KYC Liveness Verification State Machine',
    code: `stateDiagram-v2
    [*] --> StartRegistration
    StartRegistration --> FillDriverForm: Enter Name, NIC, License No, Email, Phone
    FillDriverForm --> CaptureLicenseImages: Capture Front & Back of License
    CaptureLicenseImages --> ProcessOCR: Execute Google ML Kit Text Recognition
    
    state ProcessOCR {
        [*] --> ExtractDates: Parse Date of Issue (4a) & Expiry (11)
        ExtractDates --> ValidateFormat
    }
    
    ProcessOCR --> LaunchLiveness: OCR Complete & Verified
    LaunchLiveness --> DetectFacialLandmarks: Stream Camera Video Frames
    
    state DetectFacialLandmarks {
        [*] --> CheckBlink: Blink Probability > 0.7
        CheckBlink --> CheckSmile: Smile Probability > 0.6
    }

    DetectFacialLandmarks --> VerificationCheck
    VerificationCheck --> PassKYC: Both Liveness Actions Verified
    VerificationCheck --> FailKYC: Challenge Timed Out / Incomplete

    FailKYC --> LaunchLiveness: Retry Liveness Challenge
    PassKYC --> SubmitBackend: POST /api/kyc/verify-liveness
    SubmitBackend --> AccountActivated: Set kycVerified = true & demeritPoints = 24
    AccountActivated --> [*]`
  },
  {
    id: '11_activity_fine_issuance_suspension',
    title: 'Activity 2: Traffic Fine Issuance & Auto-Suspension Logic',
    code: `stateDiagram-v2
    [*] --> SelectDriverAndOffense
    SelectDriverAndOffense --> ValidateInputs: Validate License, Vehicle, Offense, Place
    ValidateInputs --> FetchCurrentDemerits: Query Driver Demerit Balance
    FetchCurrentDemerits --> CalculateDeduction: Extract offense.demeritValue (P1-P4)

    CalculateDeduction --> ComputeNewBalance: New Balance = max(0, Current - Deduction)
    
    state ComputeNewBalance {
        [*] --> EvaluateZero
    }

    EvaluateZero --> PointsRemaining: New Balance > 0
    EvaluateZero --> PointsExhausted: New Balance == 0

    PointsRemaining --> UpdateActiveDriver: Status remains ACTIVE, Rating recalculated
    PointsExhausted --> SuspendDriver: Set licenseStatus = SUSPENDED & Record Reason

    UpdateActiveDriver --> SaveFineRecord: Create IssuedFine with status UNPAID
    SuspendDriver --> SaveFineRecord: Create IssuedFine with status UNPAID

    SaveFineRecord --> DispatchDualAlerts: Trigger FCM Push + SendGrid Email
    DispatchDualAlerts --> [*]`
  },
  {
    id: '12_activity_payhere_settlement_reconciliation',
    title: 'Activity 3: Online Payment Checkout & Webhook Reconciliation Flow',
    code: `stateDiagram-v2
    [*] --> SelectUnpaidFine
    SelectUnpaidFine --> RequestCheckout: POST /api/payment/checkout
    RequestCheckout --> GenerateMD5: Backend Computes PayHere MD5 Signature
    GenerateMD5 --> LaunchPayHereSDK: Open PayHere Web Checkout

    LaunchPayHereSDK --> ProcessPayment: Driver Enters Payment Credentials
    ProcessPayment --> ReceiveWebhook: PayHere Dispatches POST /api/payment/notify
    
    state ReceiveWebhook {
        [*] --> VerifySignature: Re-compute MD5 Hash & Check Match
    }

    VerifySignature --> PaymentValid: MD5 Match & status_code == 2
    VerifySignature --> PaymentFraud: MD5 Mismatch / Invalid Hash

    PaymentFraud --> RejectTransaction: Return HTTP 400 Bad Request
    PaymentValid --> SettleCitation: Set IssuedFine status = PAID & Record paymentId
    
    SettleCitation --> PaymentSuccessScreen: Display Green Receipt
    RejectTransaction --> [*]
    PaymentSuccessScreen --> [*]`
  },
  {
    id: '13_activity_demerit_recovery_cron',
    title: 'Activity 4: Demerit Point Recovery Engine (Automated & On-Demand)',
    code: `stateDiagram-v2
    [*] --> TriggerEvent: Cron Trigger (1st of Month) OR Manual Trigger (Admin)
    TriggerEvent --> CheckMasterSwitch: Query SystemConfig.recoveryEnabled

    state CheckMasterSwitch {
        [*] --> EvaluateSwitch
    }

    EvaluateSwitch --> AbortRun: recoveryEnabled == false
    EvaluateSwitch --> CheckCleanPeriod: recoveryEnabled == true

    CheckCleanPeriod --> QueryEligibleDrivers: Drivers with demerits < 24 & clean record >= 30 days
    QueryEligibleDrivers --> ExecuteBatchUpdate: Add monthlyRecoveryPoints (Default: 2, Max: 24)
    ExecuteBatchUpdate --> RecalculateScore: Update ratingScore (0.0 - 5.0) & demeritLevel
    RecalculateScore --> NotifyDrivers: Dispatch Push Notification + Recovery Email
    NotifyDrivers --> UpdateLastRunAt: Set SystemConfig.lastRecoveryRunAt = Now
    
    AbortRun --> [*]
    UpdateLastRunAt --> [*]`
  },
  {
    id: '14_activity_emergency_sos_dispatch',
    title: 'Activity 5: Geospatial Emergency SOS Broadcast & Officer Siren Dispatch',
    code: `stateDiagram-v2
    [*] --> DriverPressesSOS: Tap Emergency SOS on Mobile App
    DriverPressesSOS --> FetchGPSCoordinates: Capture Real-Time Latitude & Longitude
    FetchGPSCoordinates --> PostSOSToBackend: POST /api/sos/trigger
    
    PostSOSToBackend --> QueryNearbyOfficers: Execute MongoDB 2dsphere $near Spatial Query
    
    state QueryNearbyOfficers {
        [*] --> FilterRadius: $maxDistance: 5,000m (5km)
        FilterRadius --> FilterState: appState IN ('FOREGROUND', 'BACKGROUND')
    }

    QueryNearbyOfficers --> DiscoveredOfficers: Return Active Police FCM Tokens
    DiscoveredOfficers --> BroadcastFCMPayload: High-Priority FCM Push with Emergency Sound
    BroadcastFCMPayload --> TriggerSirenOnDevice: Police Device Plays Audio Siren & Shows Route Map
    TriggerSirenOnDevice --> [*]`
  },
  {
    id: '15_entity_relationship_diagram_erd',
    title: 'Comprehensive Entity Relationship Diagram (ERD) with Constraints & Cardinalities',
    code: `erDiagram
    DRIVERS ||--o{ ISSUED_FINES : "incurs"
    OFFENSES ||--o{ ISSUED_FINES : "classifies"
    POLICE ||--o{ ISSUED_FINES : "issues"
    ISSUED_FINES ||--o| PAYMENT_TRANSACTIONS : "settled_via"
    DRIVERS ||--o{ ACCIDENT_REPORTS : "files"
    STATIONS ||--o{ ACCIDENT_REPORTS : "receives"
    STATIONS ||--o{ POLICE : "assigns"
    POLICE ||--o{ OFFICER_SESSIONS : "logs"
    POLICE ||--o| PRE_APPROVED_OFFICERS : "validated_against"
    STATIONS ||--o{ VERIFICATIONS : "issues"
    ADMINS ||--o{ ADMIN_SESSIONS : "creates"
    ADMINS ||--|| SYSTEM_CONFIGS : "maintains"

    DRIVERS {
        ObjectId _id PK
        string nic UK
        string licenseNumber UK
        string name
        string email UK
        string phone
        string password
        number demeritPoints
        number ratingScore
        string licenseStatus
        string demeritLevel
        boolean kycVerified
        boolean isVerified
        boolean emailIsVerified
        string vehicleNumber
        string addressLine1
        string addressLine2
        string city
        string postalCode
        string licenseExpiryDate
        string licenseIssueDate
        string dateOfBirth
        string fcmToken
        date lastOffenseDate
        date suspendedAt
        string suspensionReason
    }

    POLICE {
        ObjectId _id PK
        string badgeNumber UK
        string name
        string email UK
        string nic UK
        string phone
        string password
        string policeStation FK
        string position
        string role
        GeoJSON location
        string appState
        boolean isActive
        string fcmToken
        date lastActiveTime
        date lastLoginTime
        GeoJSON lastLoginLocation
        date lastLogoutTime
    }

    ISSUED_FINES {
        ObjectId _id PK
        string licenseNumber FK
        string vehicleNumber
        ObjectId offenseId FK
        string offenseName
        number amount
        string place
        string province
        string district
        string policeStation FK
        string policeOfficerId FK
        string status
        string paymentId
        string paymentMethod
        number gatewayFee
        number netAmount
        date paidAt
        number demeritPoints
        date date
        string disputeReason
        string paymentNotes
    }

    OFFENSES {
        ObjectId _id PK
        string offenseName UK
        number amount
        string description
        string sectionOfAct
        number demeritValue
        string category
    }

    PAYMENT_TRANSACTIONS {
        ObjectId _id PK
        string orderId FK
        string gatewayPaymentId UK
        string merchantId
        number amount
        string currency
        string statusCode
        string statusMessage
        string paymentMethod
        string cardHolderName
        string cardNoMasked
        string md5sig
        date processedAt
        boolean isVerified
    }

    ACCIDENT_REPORTS {
        ObjectId _id PK
        string driverLicense FK
        string driverName
        string driverPhone
        string accidentType
        string description
        GeoJSON location
        string province
        string district
        string policeDivision
        string locationAddress
        number officersNotified
        string stationNotified FK
        string status
        string acknowledgedBy
        string resolvedBy
        date reportedAt
    }

    STATIONS {
        ObjectId _id PK
        string stationCode UK
        string name
        string district
        string province
        string officialEmail
        string phoneNumber
        GeoJSON location
    }

    OFFICER_SESSIONS {
        ObjectId _id PK
        string badgeNumber FK
        string officerName
        string policeStation
        date loginTime
        GeoJSON loginLocation
        date logoutTime
        GeoJSON logoutLocation
        number sessionDurationMinutes
    }

    PRE_APPROVED_OFFICERS {
        ObjectId _id PK
        string badgeNumber UK
        boolean isRegistered
        date registeredAt
        string notes
    }

    VERIFICATIONS {
        ObjectId _id PK
        string badgeNumber FK
        string stationCode FK
        string otp
        date expiresAt
        date createdAt
    }

    ADMINS {
        ObjectId _id PK
        string name
        string email UK
        string password
        string role
        boolean isTwoFactorEnabled
        string twoFactorSecret
        date lastLoginAt
        number failedLoginAttempts
        boolean accountLocked
    }

    ADMIN_SESSIONS {
        ObjectId _id PK
        ObjectId userId FK
        string sessionToken UK
        string refreshTokenHash
        string ipAddress
        string userAgent
        date expiresAt
        boolean isValid
    }

    SYSTEM_CONFIGS {
        ObjectId _id PK
        number accidentNotificationRadiusKm
        number emergencySosRadiusKm
        number officerLogoutGracePeriodMinutes
        number defaultDemeritPoints
        number monthlyRecoveryPoints
        number cleanRecordDays
        number recoveryPeriodMonths
        boolean recoveryEnabled
        date lastRecoveryRunAt
        number finePaymentGraceDays
        boolean enableOnlinePayments
        boolean allowDisputeSubmissions
        number sessionTimeoutMinutes
        number maxFailedLoginAttempts
        number jwtExpiryMinutes
        boolean require2FAForAdmins
    }`
  }
];

function fetchUrl(url, isBinary = false) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return fetchUrl(res.headers.location, isBinary).then(resolve).catch(reject);
        }
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode} from ${url}`));
        }
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const buffer = Buffer.concat(chunks);
          resolve(isBinary ? buffer : buffer.toString('utf8'));
        });
      })
      .on('error', reject);
  });
}

async function generateAll() {
  console.log(`🚀 Starting generation of ${diagrams.length} thesis-grade system diagrams...`);

  for (const d of diagrams) {
    console.log(`\n⏳ Rendering: [${d.id}] ${d.title}...`);

    const base64Code = Buffer.from(d.code).toString('base64');

    // 1. Fetch & Save SVG
    try {
      const svgUrl = `https://mermaid.ink/svg/${base64Code}`;
      let svgContent = await fetchUrl(svgUrl, false);

      // Inject solid white canvas background if not present
      if (!svgContent.includes('id="svg-bg-canvas"')) {
        const match = svgContent.match(/<svg[^>]*>/);
        if (match) {
          const svgTag = match[0];
          const newSvgTag = `${svgTag}\n<rect id="svg-bg-canvas" x="0" y="0" width="100%" height="100%" fill="#ffffff" style="fill:#ffffff;"/>`;
          svgContent = svgContent.replace(svgTag, newSvgTag);
        }
      }

      const svgPath = path.join(outputDir, `${d.id}.svg`);
      fs.writeFileSync(svgPath, svgContent, 'utf8');
      console.log(`   ✅ Saved SVG: ${d.id}.svg (${(svgContent.length / 1024).toFixed(1)} KB)`);
    } catch (err) {
      console.error(`   ❌ Failed to generate SVG for ${d.id}:`, err.message);
    }

    // 2. Fetch & Save PNG
    try {
      const pngUrl = `https://mermaid.ink/img/${base64Code}?bgColor=FFFFFF`;
      const pngBuffer = await fetchUrl(pngUrl, true);
      const pngPath = path.join(outputDir, `${d.id}.png`);
      fs.writeFileSync(pngPath, pngBuffer);
      console.log(`   ✅ Saved PNG: ${d.id}.png (${(pngBuffer.length / 1024).toFixed(1)} KB)`);
    } catch (err) {
      console.error(`   ❌ Failed to generate PNG for ${d.id}:`, err.message);
    }
  }

  console.log('\n🎉 ALL 15 ARCHITECTURAL DIAGRAMS GENERATED WITH SOLID WHITE CANVAS & EXPORTED SUCCESSFULLY!');
}

generateAll().catch(console.error);
