// scripts/seedSpotFines.js
//
// Seeds the 33 Sri Lanka spot-fine offences into the `offenses` collection.
// Source: Motor Traffic Act — Gazette Extraordinary No. 2054/9 (15 January 2018).
//
// Demerit weights (out of DEMERIT.DEFAULT_POINTS = 24):
//   2 = MINOR     — paperwork / equipment / minor nuisance
//   4 = MODERATE  — unsafe practice, risk to occupants or other road users
//   6 = SERIOUS   — directly dangerous driving behaviour
//   8 = CRITICAL  — high risk of serious injury / loss of life
//
// Usage:
//   npm run seed:offenses                 -> upsert the 33 offences and hide old non-spot-fine offences
//   npm run seed:offenses -- --keep-legacy -> upsert only, leave old offences visible in the dropdown
//
// Safe to run multiple times (upsert by offenseCode). Old offences are never deleted,
// so issued fines that reference them keep working.

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const Offense = require('../models/offenseModel');
const { DEMERIT } = require('../config/constants');

const SPOT_FINES = [
  { no: 1,  section: '21, 22, 23, 73, 74(1)', amount: 1000, points: 2, name: 'Failure to Display Vehicle Identification Marks / Number Plates', description: 'Driving a vehicle without the registration / identification marks displayed as required.' },
  { no: 2,  section: '38',     amount: 1000, points: 2, name: 'No Valid Revenue License Displayed', description: 'Using a motor vehicle without displaying a valid revenue license.' },
  { no: 3,  section: '45',     amount: 1000, points: 4, name: 'Using Vehicle Contrary to Revenue License Terms', description: 'Using a motor vehicle for a purpose not permitted by its revenue license.' },
  { no: 4,  section: '123(2)', amount: 1000, points: 4, name: 'Unauthorized Use of Emergency Vehicle Lights / Siren', description: 'Fitting or using emergency signals on a vehicle without authorization.' },
  { no: 5,  section: '128A',   amount: 1000, points: 4, name: 'Special Purpose Vehicle Without License', description: 'Using a special purpose vehicle without the required license.' },
  { no: 6,  section: '128C',   amount: 1000, points: 8, name: 'Transporting Hazardous Goods Without Approval', description: 'Carrying dangerous or hazardous goods without the required approval.' },
  { no: 7,  section: '130',    amount: 1000, points: 6, name: 'Driving Without License for Vehicle Class', description: 'Driving a vehicle of a class not covered by the driving license held.' },
  { no: 8,  section: '135',    amount: 1000, points: 2, name: 'Failure to Carry Driving License', description: 'Failure to carry a valid driving license while driving.' },
  { no: 9,  section: '139A',   amount: 2000, points: 4, name: 'Driving Instruction Without Instructor License', description: 'Giving driving instruction without a valid instructor\'s license.' },
  { no: 10, section: '140, 141', amount: 3000, points: 6, name: 'Exceeding Speed Limit', description: 'Driving above the speed limit prescribed for the vehicle class or road.' },
  { no: 11, section: '148',    amount: 2000, points: 4, name: 'Violation of Rules of the Road', description: 'Failure to comply with the rules of the road (lane discipline, overtaking, giving way, etc.).' },
  { no: 12, section: '152',    amount: 1000, points: 6, name: 'Driving Without Proper Control of Vehicle', description: 'Driving in a position or manner where the driver does not have full control of the vehicle.' },
  { no: 13, section: '153',    amount: 1000, points: 4, name: 'Unsafe Positioning of Vehicle on Road', description: 'Keeping the vehicle in a position on the road that endangers other road users.' },
  { no: 14, section: '154',    amount: 1000, points: 6, name: 'Using Mobile Phone While Driving', description: 'Using a mobile phone or other communication device while driving.' },
  { no: 15, section: '155',    amount: 1000, points: 2, name: 'Improper Use of Horn / Warning Device', description: 'Unnecessary or improper use of the horn or audible warning device.' },
  { no: 16, section: '155A',   amount: 1000, points: 2, name: 'Excessive Smoke / Emission Control Violation', description: 'Emitting excessive smoke or failing to comply with emission controls.' },
  { no: 17, section: '156',    amount: 500,  points: 2, name: 'Failure to Give Way at Ferry / Narrow Bridge', description: 'Refusing right of way at a ferry or narrow bridge.' },
  { no: 18, section: '157',    amount: 1000, points: 2, name: 'Exceeding Front Seat Capacity', description: 'Carrying more persons in the driver\'s seat area than permitted.' },
  { no: 19, section: '157A',   amount: 1000, points: 4, name: 'Not Wearing Seat Belt', description: 'Driver or front passenger not wearing a seat belt.' },
  { no: 20, section: '158',    amount: 1000, points: 4, name: 'Riding Without Protective Helmet', description: 'Riding or being a pillion rider on a motorcycle without a protective helmet.' },
  { no: 21, section: '159',    amount: 1000, points: 4, name: 'Allowing Persons to Cling to Moving Vehicle', description: 'Allowing a person to be carried on the running board, footboard or outside of a moving vehicle.' },
  { no: 22, section: '160',    amount: 1000, points: 2, name: 'Excessive / Prohibited Noise', description: 'Causing excessive or prohibited noise from the vehicle.' },
  { no: 23, section: '162',    amount: 2000, points: 6, name: 'Disobeying Directions of Police Officer', description: 'Failure to obey the directions or signals given by a police officer.' },
  { no: 24, section: '164',    amount: 1000, points: 6, name: 'Disobeying Traffic Signs / Signals', description: 'Failure to comply with road signs, traffic lights or road markings.' },
  { no: 25, section: '165',    amount: 1000, points: 8, name: 'Failure to Take Safety Measures After Accident', description: 'Failure to stop or take required safety measures after an accident.' },
  { no: 26, section: '166',    amount: 1000, points: 2, name: 'Unlawful Parking / Stopping', description: 'Parking or stopping a vehicle in a prohibited or dangerous place.' },
  { no: 27, section: '167',    amount: 2000, points: 4, name: 'No Safety Precautions for Broken Down Vehicle', description: 'Failure to place warning signs / lights for a broken-down vehicle.' },
  { no: 28, section: '178',    amount: 500,  points: 4, name: 'Carrying Passengers / Goods Over Capacity', description: 'Carrying persons or goods in excess of the authorized number or weight.' },
  { no: 29, section: '179',    amount: 500,  points: 4, name: 'Omnibus Carrying Passengers Over Capacity', description: 'Omnibus carrying passengers in excess of the permitted number.' },
  { no: 30, section: '188',    amount: 500,  points: 4, name: 'Lorry Overloading', description: 'Lorry carrying a load in excess of the permitted weight.' },
  { no: 31, section: '189',    amount: 500,  points: 2, name: 'Exceeding Persons Allowed in Lorry', description: 'Carrying persons in a lorry in excess of the permitted number.' },
  { no: 32, section: '190',    amount: 1000, points: 2, name: 'Violation of Goods Transport Regulations', description: 'Failure to comply with regulations on transport of goods.' },
  { no: 33, section: '196',    amount: 500,  points: 2, name: 'No Valid Emission Test / Fitness Certificate', description: 'Using a vehicle without a valid emission test or fitness certificate.' },
];

const run = async () => {
  const keepLegacy = process.argv.includes('--keep-legacy');

  await mongoose.connect(process.env.MONGO_URI);
  console.log('[seedSpotFines] Connected to MongoDB');

  const ops = SPOT_FINES.map((f) => {
    const offenseCode = `SF-${String(f.no).padStart(2, '0')}`;
    return {
      updateOne: {
        filter: { offenseCode },
        update: {
          $set: {
            offenseCode,
            spotFineNo: f.no,
            offenseName: f.name,
            sectionOfAct: f.section,
            amount: f.amount,
            demeritValue: f.points,
            severity: DEMERIT.SEVERITY_BY_POINTS[f.points],
            description: f.description,
            isSpotFine: true,
            isActive: true,
          },
        },
        upsert: true,
      },
    };
  });

  const result = await Offense.bulkWrite(ops);
  console.log(`[seedSpotFines] Spot fines — inserted: ${result.upsertedCount}, updated: ${result.modifiedCount}`);

  if (!keepLegacy) {
    // Hide pre-existing offenses from the dropdown (not deleted — issued fines still reference them)
    const legacy = await Offense.updateMany(
      { isSpotFine: { $ne: true }, isActive: { $ne: false } },
      { $set: { isActive: false } }
    );
    console.log(`[seedSpotFines] Legacy offenses hidden from dropdown: ${legacy.modifiedCount}`);
  }

  const activeCount = await Offense.countDocuments({ isActive: { $ne: false } });
  console.log(`[seedSpotFines] Active offenses now available: ${activeCount}`);

  await mongoose.disconnect();
};

if (require.main === module) {
  run().catch((err) => {
    console.error('[seedSpotFines] Failed:', err.message);
    process.exit(1);
  });
}

module.exports = { SPOT_FINES };
