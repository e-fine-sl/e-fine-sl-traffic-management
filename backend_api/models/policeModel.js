const mongoose = require('mongoose');
const { ROLES } = require('../config/constants');

const policeSchema = mongoose.Schema({
 
    name: { 
        type: String, 
        required: true 
    },
    email: { 
        type: String, 
        required: true, 
        unique: true 
    },
    badgeNumber: { 
        type: String, 
        required: true, 
        unique: true 
    },
    nic: {
        type: String,
        required: true,
        unique: true
    },
    phone: {
        type: String,
        required: true
    },
    password: { 
        type: String, 
        required: true 
    },


    policeStation: { 
        type: String, 
        required: true 
    },
    position: { 
        type: String, 
        required: true //  OIC, Sergeant, Constable
    },
    profileImage: { 
        type: String, 
        default: 'https://cdn-icons-png.flaticon.com/512/206/206853.png' // Default පින්තූරයක්
    },

    // --- Role 
    role: { 
        type: String, 
        default: ROLES.OFFICER 
    },
}, {
    timestamps: true
   });  // CreatedAt, UpdatedAt 


module.exports = mongoose.model('Police', policeSchema,'polices');