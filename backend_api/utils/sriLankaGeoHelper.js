const DISTRICT_BOUNDS = {
  'Colombo':        { province: 'Western',       bounds: [6.7500, 7.0500, 79.7800, 80.0200] },
  'Gampaha':        { province: 'Western',       bounds: [6.9500, 7.3500, 79.8500, 80.2500] },
  'Kalutara':       { province: 'Western',       bounds: [6.3500, 6.8000, 79.9000, 80.5000] },
  'Kandy':          { province: 'Central',       bounds: [6.9000, 7.5000, 80.3500, 81.2000] },
  'Matale':         { province: 'Central',       bounds: [7.3500, 8.1000, 80.4000, 81.0000] },
  'Nuwara Eliya':   { province: 'Central',       bounds: [6.7500, 7.1000, 80.6000, 81.1000] },
  'Galle':          { province: 'Southern',      bounds: [5.9500, 6.4000, 80.0000, 80.7000] },
  'Matara':         { province: 'Southern',      bounds: [5.8500, 6.2000, 80.4500, 81.2000] },
  'Hambantota':     { province: 'Southern',      bounds: [6.0000, 6.5000, 80.7500, 81.5000] },
  'Jaffna':         { province: 'Northern',      bounds: [9.5000, 9.8500, 79.9000, 80.4000] },
  'Kilinochchi':    { province: 'Northern',      bounds: [8.9500, 9.5000, 80.0000, 80.6000] },
  'Mannar':         { province: 'Northern',      bounds: [8.6500, 9.2000, 79.7500, 80.3000] },
  'Vavuniya':       { province: 'Northern',      bounds: [8.5500, 9.1000, 80.2500, 80.8500] },
  'Mullaitivu':     { province: 'Northern',      bounds: [8.9500, 9.4500, 80.4500, 81.1000] },
  'Trincomalee':    { province: 'Eastern',       bounds: [7.8500, 9.0000, 80.9000, 81.5000] },
  'Batticaloa':     { province: 'Eastern',       bounds: [7.4500, 8.3500, 81.2500, 81.8500] },
  'Ampara':         { province: 'Eastern',       bounds: [6.8500, 7.7000, 81.0500, 81.9500] },
  'Kurunegala':     { province: 'North Western', bounds: [7.2500, 8.0500, 79.9500, 80.8500] },
  'Puttalam':       { province: 'North Western', bounds: [7.7500, 8.5000, 79.6500, 80.3500] },
  'Anuradhapura':   { province: 'North Central', bounds: [7.9000, 9.0000, 80.0500, 81.0500] },
  'Polonnaruwa':    { province: 'North Central', bounds: [7.5500, 8.3500, 80.8000, 81.5000] },
  'Badulla':        { province: 'Uva',           bounds: [6.5500, 7.2000, 80.7500, 81.5000] },
  'Monaragala':     { province: 'Uva',           bounds: [6.1000, 7.0000, 81.0000, 81.9000] },
  'Ratnapura':      { province: 'Sabaragamuwa',  bounds: [6.3500, 6.9500, 80.2500, 81.0000] },
  'Kegalle':        { province: 'Sabaragamuwa',  bounds: [7.0000, 7.4000, 80.1500, 80.7500] }
};

const POLICE_DIVISIONS = {
  'Colombo':      ['Colombo','Dehiwela','Nugegoda','Sri Jayawardenepura Kotte','Kelaniya','Moratuwa','Homagama','Kaduwela','Boralesgamuwa'],
  'Gampaha':      ['Gampaha','Negombo','Ja-Ela','Wattala','Minuwangoda','Divulapitiya','Mirigama'],
  'Kalutara':     ['Kalutara','Panadura','Horana','Mathugama','Beruwala'],
  'Kandy':        ['Kandy','Peradeniya','Katugastota','Gampola','Nawalapitiya','Akurana'],
  'Matale':       ['Matale','Dambulla','Galewela','Ukuwela'],
  'Nuwara Eliya': ['Nuwara Eliya','Hatton','Talawakelle','Ragala'],
  'Galle':        ['Galle','Hikkaduwa','Elpitiya','Balapitiya','Ambalangoda'],
  'Matara':       ['Matara','Weligama','Dikwella','Akuressa'],
  'Hambantota':   ['Hambantota','Tangalle','Tissamaharama','Beliatta'],
  'Jaffna':       ['Jaffna','Chavakachcheri','Point Pedro','Kilinochchi'],
  'Kilinochchi':  ['Kilinochchi','Paranthan'],
  'Mannar':       ['Mannar','Murunkan'],
  'Vavuniya':     ['Vavuniya','Nedunkerni'],
  'Mullaitivu':   ['Mullaitivu','Oddusuddan'],
  'Trincomalee':  ['Trincomalee','Kinniya','Muttur'],
  'Batticaloa':   ['Batticaloa','Kattankudy','Valaichenai'],
  'Ampara':       ['Ampara','Kalmunai','Sammanthurai','Pottuvil'],
  'Kurunegala':   ['Kurunegala','Kuliyapitiya','Nikaweratiya','Maho','Wariyapola'],
  'Puttalam':     ['Puttalam','Chilaw','Wennappuwa','Marawila'],
  'Anuradhapura': ['Anuradhapura','Kekirawa','Medawachchiya','Mihintale'],
  'Polonnaruwa':  ['Polonnaruwa','Medirigiriya','Hingurakgoda'],
  'Badulla':      ['Badulla','Bandarawela','Haputale','Welimada','Mahiyanganaya'],
  'Monaragala':   ['Monaragala','Wellawaya','Buttala'],
  'Ratnapura':    ['Ratnapura','Embilipitiya','Balangoda','Pelmadulla'],
  'Kegalle':      ['Kegalle','Mawanella','Warakapola','Rambukkana']
};

/**
 * Resolves a given latitude and longitude to a Province, District, and Police Division.
 * @param {number} lat - Latitude
 * @param {number} lng - Longitude
 * @returns {Object} { province, district, policeDivision }
 */
const resolveLocation = (lat, lng) => {
  for (const [district, data] of Object.entries(DISTRICT_BOUNDS)) {
    const [minLat, maxLat, minLng, maxLng] = data.bounds;
    if (lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng) {
      return {
        province: data.province,
        district: district,
        policeDivision: POLICE_DIVISIONS[district][0]
      };
    }
  }
  
  return {
    province: 'Unknown',
    district: 'Unknown',
    policeDivision: 'Unknown'
  };
};

module.exports = { resolveLocation, DISTRICT_BOUNDS, POLICE_DIVISIONS };
