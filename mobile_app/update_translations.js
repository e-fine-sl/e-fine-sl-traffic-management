const fs = require('fs');
const path = require('path');

const newKeysEn = {
  "dashboard_fines_today": "Fines Issued Today",
  "dashboard_vehicles_checked": "Vehicles Checked",
  "dashboard_recent_fines": "Recent Fines Activity",
  "dashboard_sos_title": "Emergency SOS",
  "dashboard_sos_confirm": "Call for immediate backup at your current location?",
  "dashboard_sos_send": "Dispatch Backup"
};

const newKeysSi = {
  "dashboard_fines_today": "අද දිනයේ නිකුත් කළ දඩ",
  "dashboard_vehicles_checked": "පරීක්‍ෂා කළ වාහන",
  "dashboard_recent_fines": "මෑතකාලීන දඩ ක්‍රියාකාරකම්",
  "dashboard_sos_title": "හදිසි SOS",
  "dashboard_sos_confirm": "මෙම ස්ථානයට වහාම අමතර පොලිස් සහාය අවශ්‍යද?",
  "dashboard_sos_send": "සහාය ඉල්ලන්න"
};

const newKeysTa = {
  "dashboard_fines_today": "இன்று வழங்கப்பட்ட அபராதங்கள்",
  "dashboard_vehicles_checked": "சோதிக்கப்பட்ட வாகனங்கள்",
  "dashboard_recent_fines": "சமீபத்திய அபராதச் செயல்பாடுகள்",
  "dashboard_sos_title": "அவசர SOS",
  "dashboard_sos_confirm": "இவ்விடத்திற்கு உடனடியாக கூடுதல் காவல்துறை உதவி தேவையா?",
  "dashboard_sos_send": "உதவி கோரு"
};

const keysMap = {
  'en.json': newKeysEn,
  'si.json': newKeysSi,
  'ta.json': newKeysTa
};

for (const [file, keys] of Object.entries(keysMap)) {
  const filePath = path.join(__dirname, 'assets/translations', file);
  if (fs.existsSync(filePath)) {
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    if (!data.police) data.police = {};
    Object.assign(data.police, keys);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    console.log(`Updated ${file}`);
  }
}
