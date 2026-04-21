# 🆘 Quick Troubleshooting Reference Card

## Problem: Recent Fines Widget Shows "No recent fines available"

### 🎯 Quick Fix (5 minutes)

```bash
# Step 1: Test Backend
cd backend_api
node test_dashboard_stats.js OP-001

# Expected output:
# ✅ Connected to MongoDB
# Total fines: 15
# Fines for OP-001: 5
# Status Code: 200
# ✅ Response received successfully
```

If ❌ Failed → Go to **Section A**
If ✅ Success → Go to **Section B**

---

## Section A: Backend Not Working

### A1. Route Not Found (404 Error)

**Error Message:**
```
Status Code: 404
Endpoint not found
```

**Fix:**
```bash
# Edit backend_api/routes/fineRoutes.js
# Line 27 should have:
router.get('/dashboard-stats', getDashboardStats);

# Restart backend:
npm start
```

### A2. Server Error (500 Error)

**Error Message:**
```
Status Code: 500
Failed to fetch dashboard stats
```

**Fix:**
```bash
# 1. Check backend console for error
# 2. Look for lines starting with "❌"
# 3. Restart backend:
npm start

# 4. If still failing, check MongoDB:
mongosh
db.issuedfines.countDocuments()  # Should show > 0
```

### A3. No Fines in Database

**Error Message:**
```
Total fines: 0
Fines for OP-001: 0
```

**Fix:**
```
1. Open mobile app
2. Go to "New Fine" screen
3. Issue 2-3 test fines
4. Go back to Dashboard
5. Recent fines should appear
```

### A4. Officer ID Mismatch

**Error Message:**
```
Fines for OP-001: 0
Officers with fines: OP-002, OP-003
```

**Fix:**
```
1. Check what officer ID you're logged in as
2. Use that ID in the test:
   node test_dashboard_stats.js OP-002
3. Or issue test fines as the current officer
```

---

## Section B: Backend Working, Frontend Not

### B1. Flutter Shows Logs But No Fines Display

**Signs:**
```
[PoliceDashboardService] Response Status Code: 200
[PoliceHomeScreen] Recent Fines Loaded: 3 fines
But widget still shows "No recent fines available"
```

**Fix:**
```dart
// Add this to police_home_screen.dart initState()
Future<void> _debugPrintStorageValues() async {
  String? badge = await _storage.read(key: PrefKeys.badgeNumber);
  debugPrint('[DEBUG] Badge: $badge');
  debugPrint('[DEBUG] Recent Fines: $_recentFines');
}
```

Then check if `_recentFines` is null or empty.

### B2. Status Badges Not Showing

**Problem:** Shows "No recent fines available" even though backend returns data

**Cause:** `fines == null` check is failing

**Fix:**
```dart
// In RecentFinesWidget, add logging:
debugPrint('[DEBUG] fines == null: ${fines == null}');
debugPrint('[DEBUG] fines!.isEmpty: ${fines?.isEmpty ?? "null"}');
debugPrint('[DEBUG] fines length: ${fines?.length}');
```

### B3. Date Not Formatting

**Problem:** Date shows as "N/A" instead of "21 Apr 2026"

**Cause:** Date parsing error

**Fix:**
```dart
// Verify date format from backend:
debugPrint('[DEBUG] Raw date: ${fine['date']}');

// Date should be ISO format:
// ✅ Correct: "2026-04-21T10:30:00.000Z"
// ❌ Wrong: "2026-04-21" or "21/04/2026"
```

---

## Common Error Messages & Fixes

### ❌ "No recent fines available"
```
Likely cause: Fines array is empty or null
1. Check backend test: node test_dashboard_stats.js OP-001
2. Should show "Fines for OP-001: X" (X > 0)
3. If 0, issue test fines first
```

### ❌ "Connection Error"
```
Likely cause: Backend not running or wrong API URL
1. Check backend running: npm start
2. Check API URL in AppConstants
3. Restart app: flutter run
```

### ❌ "Token or Badge is NULL"
```
Likely cause: Not logged in or session expired
1. Login again
2. Wait for secure storage to initialize
3. Pull-to-refresh dashboard
```

### ❌ Status Code 404
```
Likely cause: Route not registered
1. Check fineRoutes.js has the route
2. Restart backend
3. Clear Flutter cache: flutter clean
```

### ❌ Status Code 500
```
Likely cause: Database or query error
1. Check backend console for error
2. Verify fines exist in database
3. Check officer ID is correct
4. Restart backend
```

---

## Verification Checklist ✅

Run through these in order:

```
1. ☐ Backend running?
   npm start
   
2. ☐ Route registered?
   grep -r "dashboard-stats" backend_api/routes/
   
3. ☐ Fines in database?
   mongosh
   db.issuedfines.find({policeOfficerId: "OP-001"}).limit(3)
   
4. ☐ API endpoint working?
   node test_dashboard_stats.js OP-001
   
5. ☐ App can reach backend?
   Ping: curl http://localhost:5000/
   
6. ☐ App has valid token?
   Check Flutter logs: [PoliceDashboardService] Calling API
   
7. ☐ Widget displaying?
   Pull-to-refresh dashboard and check
```

If all ☐ checked and still not working → See **Advanced Debugging**

---

## Advanced Debugging

### Enable HTTP Logging

**In Flutter app** (`api_logger.dart`):
```dart
// Add before http.get():
debugPrint('📤 REQUEST: $uri');
debugPrint('📤 HEADERS: $headers');

// Add after response:
debugPrint('📥 RESPONSE: ${response.statusCode}');
debugPrint('📥 BODY: ${response.body}');
```

### Backend Console Logging

**In fineController.js** (`getDashboardStats`):
```javascript
console.log('🔍 policeOfficerId:', policeOfficerId);
console.log('📅 Date range:', today, '-', tomorrow);
console.log('✅ dailyStats:', dailyStatsResult);
console.log('✅ recentFines:', recentFines);
```

### MongoDB Query Test

```javascript
// In mongosh
db.issuedfines.find({
  policeOfficerId: "OP-001"
}).sort({date: -1}).limit(3)

// Should return 1-3 documents
// Each should have: vehicleNumber, offenseName, amount, date, status
```

---

## Need More Help?

1. **Check these files:**
   - [DASHBOARD_DEBUGGING_GUIDE.md](DASHBOARD_DEBUGGING_GUIDE.md) - Comprehensive guide
   - [DASHBOARD_UPDATES_SUMMARY.md](DASHBOARD_UPDATES_SUMMARY.md) - What changed
   - [WIDGET_COMPARISON.md](WIDGET_COMPARISON.md) - UI improvements

2. **Run tests:**
   - `node test_dashboard_stats.js OP-001` - Test backend
   - `flutter run` - Test app in debug mode

3. **Check console logs:**
   - Look for `[PoliceDashboardService]` messages
   - Look for `[PoliceHomeScreen]` messages
   - Look for `[RecentFinesWidget]` messages

4. **Verify data flow:**
   ```
   App → Service → API → Backend → Database
   ```
   Test each step individually

---

## Quick Stats

| Component | Status | Test Command |
|-----------|--------|--------------|
| Backend Server | ? | `npm start` |
| Database | ? | `mongosh` → `db.issuedfines.count()` |
| API Endpoint | ? | `node test_dashboard_stats.js OP-001` |
| Flutter Service | ? | Check console logs |
| Widget Display | ? | Run app and check UI |

---

**Remember:** Always check the console logs first! They tell you exactly what's happening! 🔍
