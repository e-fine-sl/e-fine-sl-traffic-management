const mongoose = require('mongoose');
const { DEMERIT } = require('../config/constants');

const offenseSchema = mongoose.Schema(
  {
    offenseName: {
      type: String,
      required: true,
      unique: true, // Ekama waradda deparak liyawenne na
    },
    amount: {
      type: Number,
      required: true,
    },
    description: {
      type: String,
      required: false,
    },
    sectionOfAct: { // Panatha (Example: 123-A)
      type: String,
      required: false, 
    },
    demeritValue: {
      type: Number,
      required: true,
      default: DEMERIT.OFFENSE_LEVELS.P1_MINOR,
      min: 1,
      max: DEMERIT.OFFENSE_LEVELS.P4_CRITICAL,
    }
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Offense', offenseSchema);
