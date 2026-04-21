# 🔧 Dashboard Recent Fines - Debugging Guide

## Problem: Recent Fines Not Loading

If you see "No recent fines available" but fines exist in the database, follow these steps:

---

## **STEP 1: Check Console Logs**

Open the Flutter DevTools console and look for these debug messages:

```
[PoliceDashboardService] Calling API: http://your-ip:5000/api/fines/dashboard-stats?policeOfficerId=...
[PoliceDashboardService] Response Status Code: 200
[PoliceDashboardService] Raw Response: {...}
[PoliceHomeScreen] Recent Fines Loaded: X fines
[RecentFinesWidget] isLoading: false, fines: X
```

### ❌ If you see:
- `Response Status Code: 404` → **STEP 2**
- `Response Status Code: 500` → **STEP 3**
- `Recent Fines Loaded: 0 fines` → **STEP 4**
- `Token or Badge is null` → **STEP 5**

---

## **STEP 2: Verify Backend Route Exists**

### Test the endpoint directly with Postman/cURL:

```bash
# Example 1: Using cURL
curl -X GET "http://localhost:5000/api/fines/dashboard-stats?policeOfficerId=OP-001" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"

# Example 2: Expected SUCCESS Response (200)
{
  "dailyFinesCount": 3,
  "dailyTotalAmount": 8500,
  "recentFines": [
    {
      "vehicleNumber": "ABC-1234",
      "offenseName": "Speeding",
      "amount": 5000,
      "date": "2026-04-21T10:30:00.000Z",
      "status": "UNPAID"
    },
    {
      "vehicleNumber": "XYZ-5678",
      "offenseName": "No Helmet",
      "amount": 3500,
      "date": "2026-04-21T09:15:00.000Z",
      "status": "PAID"
    },
    {
      "vehicleNumber": "DEF-9999",
      "offenseName": "Illegal Parking",
      "amount": 2000,
      "date": "2026-04-20T15:45:00.000Z",
      "status": "UNPAID"
    }
  ]
}
```

**If you get 404:** Route not registered. Check [fineRoutes.js](backend_api/routes/fineRoutes.js#L27)

---

## **STEP 3: Backend 500 Error Investigation**

Add temporary logging to the backend controller:

Edit [backend_api/controllers/fineController.js](backend_api/controllers/fineController.js#L155):

```javascript
const getDashboardStats = async (req, res) => {
  try {
    const { policeOfficerId } = req.query;
    console.log('📊 [getDashboardStats] Received policeOfficerId:', policeOfficerId);

    if (!policeOfficerId) {
      return res.status(HTTP.BAD_REQUEST).json({ message: 'Police Officer ID is required' });
    }

    // === Get Today's Date Range ===
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    console.log('📅 Date range:', today, 'to', tomorrow);

    // === Daily Stats Query ===
    console.log('🔍 Querying daily stats for officer:', policeOfficerId);
    const dailyStatsResult = await IssuedFine.aggregate([
      {
        $match: {
          policeOfficerId: policeOfficerId,
          date: { $gte: today, $lt: tomorrow }
        }
      },
      { $group: { _id: null, count: { $sum: 1 }, totalAmount: { $sum: '$amount' } } }
    ]);
    console.log('✅ Daily stats result:', dailyStatsResult);

    // === Recent Fines Query ===
    console.log('🔍 Querying recent fines for officer:', policeOfficerId);
    const recentFines = await IssuedFine.find({ policeOfficerId: policeOfficerId })
      .select('vehicleNumber offenseName amount date status -_id')
      .sort({ date: -1 })
      .limit(3)
      .lean();
    console.log('✅ Recent fines result:', recentFines);

    // ... rest of the code
  } catch (error) {
    console.error('❌ [getDashboardStats] ERROR:', error);
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to fetch dashboard stats', error: error.message });
  }
};
```

**Check your terminal output when calling the endpoint. Look for:**
- ✅ Query logs (should print the queries)
- ❌ Error messages (will show what went wrong)
- ❌ MongoDB connection issues

---

## **STEP 4: No Fines in Database for Officer**

### Check if fines exist for this officer:

Open MongoDB Compass or use this Node command:

```javascript
// In backend_api/test_db.js or your MongoDB client
const IssuedFine = require('./models/issuedFineModel');

// Count all fines
const allFines = await IssuedFine.countDocuments();
console.log('Total fines in database:', allFines);

// Count fines for specific officer
const officerFines = await IssuedFine.countDocuments({ 
  policeOfficerId: 'OP-001' // Use your actual officer ID
});
console.log('Fines for OP-001:', officerFines);

// Get sample fines
const samples = await IssuedFine.find({ policeOfficerId: 'OP-001' }).limit(3);
console.log('Sample fines:', samples);
```

### ⚠️ If 0 fines exist:
- **Solution:** Issue some test fines first!
- Go to "New Fine" screen in the app
- Create a few test fines
- They should appear in Recent Fines widget

### ⚠️ If fines exist but still not showing:
- **Check Officer ID match:**
  ```javascript
  // Get the actual officer IDs in database
  const officers = await IssuedFine.distinct('policeOfficerId');
  console.log('Officers with fines:', officers);
  
  // Check what the app is sending
  console.log('App is sending policeOfficerId:', app_badge_number);
  ```

---

## **STEP 5: Token or Badge is NULL**

### Check Secure Storage:

The app needs to store:
- `badgeNumber` (used as `policeOfficerId`)
- `token` (for Authorization header)

**Fix:** Make sure you:
1. ✅ Login successfully
2. ✅ Badge number is stored (check in AuthService)
3. ✅ Token is valid and not expired

Add this debug code to police_home_screen.dart initState:

```dart
@override
void initState() {
  super.initState();
  _debugPrintStorageValues();
  _loadUserData();
  _loadDashboardData();
}

Future<void> _debugPrintStorageValues() async {
  String? badge = await _storage.read(key: PrefKeys.badgeNumber);
  String? token = await _authService.getToken();
  debugPrint('[DEBUG] Badge Number: $badge');
  debugPrint('[DEBUG] Token: ${token?.substring(0, 20)}... (truncated)');
}
```

---

## **STEP 6: Verify Data Format**

After fixing the above, check if data displays correctly:

### In the widget, you should see:
- ✅ Recent Fines title
- ✅ 1-3 fine cards with:
  - Offense name
  - Vehicle number
  - Amount (in LKR)
  - Date & Time
  - Status badge (PAID / UNPAID)

### If data loads but displays wrong:
- Check the date format (should be "21 Apr 2026 – 10:30 AM")
- Check status colors (PAID = Green, UNPAID = Red)
- Check amount format (should be "Rs. 5000")

---

## **Quick Test Checklist**

- [ ] Backend server is running (`npm start` in backend_api/)
- [ ] Mobile app is connected to correct API base URL
- [ ] You are logged in as a police officer
- [ ] At least 1 fine exists in database for your officer ID
- [ ] Console shows "Response Status Code: 200"
- [ ] `Recent Fines Loaded: X fines` (X > 0)
- [ ] Pull-to-refresh works
- [ ] Recent fines appear after 3-5 seconds

---

## **Sample Test Data Insert**

If you need test data, run this in MongoDB:

```javascript
// Sample fine to insert
db.issuedfines.insertOne({
  licenseNumber: "DL-123456",
  vehicleNumber: "ABC-1234",
  offenseId: ObjectId("..."),  // Get a real offense ID
  offenseName: "Speeding",
  amount: 5000,
  place: "Main Road, Colombo",
  policeOfficerId: "OP-001",  // Use your badge number
  status: "UNPAID",
  demeritPoints: 2,
  date: new Date(),  // Today
  createdAt: new Date(),
  updatedAt: new Date()
});
```

---

## **Still Not Working?**

1. **Clear app cache:**
   - iOS: Xcode → Product → Clean Build Folder
   - Android: Android Studio → Build → Clean Project

2. **Restart everything:**
   - Kill backend server
   - Uninstall app
   - Rebuild and run again

3. **Enable HTTP logging:**
   - Check api_logger.dart for request/response bodies

4. **Check network tab (Flutter DevTools):**
   - See actual HTTP request/response
   - Verify headers and body format

---

## 📝 Log Examples

### ✅ SUCCESS Logs:
```
[PoliceDashboardService] Calling API: http://192.168.1.100:5000/api/fines/dashboard-stats?policeOfficerId=OP-001
[PoliceDashboardService] Response Status Code: 200
[PoliceDashboardService] Raw Response: {dailyFinesCount: 3, dailyTotalAmount: 8500, recentFines: [...]}
[PoliceDashboardService] Formatted Response: {recentFines: [...], dailyStats: {count: 3, totalAmount: 8500}}
[PoliceHomeScreen] Recent Fines Loaded: 3 fines
[RecentFinesWidget] isLoading: false, fines: 3
```

### ❌ ERROR Logs:
```
[PoliceDashboardService] Response Status Code: 404
→ Solution: Check if route is registered in fineRoutes.js

[PoliceDashboardService] Response Status Code: 500
→ Solution: Check backend console for error details

[PoliceHomeScreen] Recent Fines Loaded: 0 fines
→ Solution: Verify fines exist in database for this officer

[PoliceDashboardService] ERROR: Token or Badge is null
→ Solution: Login again or check secure storage
```

---

**Need Help?** Check the console logs first - they tell you exactly what's happening! 🚀
