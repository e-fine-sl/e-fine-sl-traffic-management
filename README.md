![e-Fine SL Logo](mobile_app/assets/icons/app_icon/app_logo.png)

# e-Fine SL Traffic Management System

[![Status](https://img.shields.io/badge/Status-Liveness%20%26%20OCR%20Integrated-success)](https://github.com/your-repo)
[![Version](https://img.shields.io/badge/Version-1.2.0--beta-blue)](https://github.com/your-repo)

This repository contains the complete source code for the e-Fine SL Traffic Management System, including the **Node.js** backend API and **Flutter** mobile application.

## Project Structure

- `backend_api/` — Node.js Express REST API for traffic management, fines, payment processing, and user authentication.
- `mobile_app/` — Flutter mobile application (Driver & Police modules).

## Current Status (Integrated)

### ✅ Mobile App (Flutter)

- **Liveness Detection (KYC):** Robust "blink and smile" sequence using Google ML Kit to verify live human presence during registration.
- **Enhanced OCR:** High-precision Sri Lankan Driving License scanning (Anchor-based extraction for Column 11 Expiry and 4a Issue dates).
- **Role-Based Access:** Distinct features for Drivers and Traffic Police.
- **Online Payments:** Full integration with **PayHere** Sandbox for paying fines.
- **Real-time Notifications:** Alerts for new fines with Officer ID and timestamps.
- **Demerit Status Card:** Real-time visualization of demerit points and suspension status.

### ✅ Backend API (Node.js/Express)

- **Admin Management Dashboard:** Advanced filtering by payment status/date and searching by Location or Officer Badge ID.
- **Driver Rating System:** Star-based rating calculation (0-5) based on demerit point deductions.
- **Secure Authentication:** JWT-based auth with OTP verification and 2FA for Admins.
- **Automated Demerit System:** Auto-deduction of points on fine issuance and monthly reinstatement.
- **Database:** MongoDB (Mongoose) schema for Users, Fines, and Offenses.

## How to Run

- See individual README files in `backend_api/` and `mobile_app/` for setup instructions.

## Next Steps / Roadmap

- **📷 Vehicle Number OCR:** Implement OCR scanning for vehicle number plates (Police side).
- **📨 SMS Alerts:** Integration with SMS gateway for offline notifications.
- **🎨 UI Enhancements:** Continued UI/UX improvements.

---
