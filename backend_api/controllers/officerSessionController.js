const Police = require('../models/policeModel');
const OfficerSession = require('../models/officerSessionModel');

/**
 * @route   PUT /api/officer/logout
 * @desc    Records logout time and location, marks officer inactive, completes session.
 */
const officerLogout = async (req, res) => {
    const tag = '[OfficerSession]';
    const { badgeNumber, lat, lng } = req.body;

    if (!badgeNumber) {
        return res.status(400).json({ success: false, message: 'badgeNumber is required' });
    }

    const logoutTime = new Date();
    const updateFields = { 
        isActive: false, 
        lastLogoutTime: logoutTime 
    };

    if (lat !== undefined && lng !== undefined && lat !== null && lng !== null) {
        const parsedLat = parseFloat(lat);
        const parsedLng = parseFloat(lng);
        if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
            updateFields.lastLoginLocation = {
                type: 'Point',
                coordinates: [parsedLng, parsedLat]
            };
        }
    }

    try {
        const officer = await Police.findOneAndUpdate(
            { badgeNumber },
            { $set: updateFields },
            { new: true }
        );

        if (!officer) {
            console.error(`${tag} Officer ${badgeNumber} not found`);
            return res.status(404).json({ success: false, message: `Officer ${badgeNumber} not found` });
        }

        // Find the most recent open session
        const session = await OfficerSession.findOne({ 
            badgeNumber, 
            logoutTime: null 
        }).sort({ loginTime: -1 });

        let sessionDurationMinutes = null;
        if (session) {
            sessionDurationMinutes = Math.floor((logoutTime - session.loginTime) / 60000);
            session.logoutTime = logoutTime;
            if (lat !== undefined && lng !== undefined) {
                session.logoutLocation = { 
                    type: 'Point', 
                    coordinates: [parseFloat(lng), parseFloat(lat)] 
                };
            }
            session.sessionDurationMinutes = sessionDurationMinutes;
            await session.save();
        }

        console.log(`${tag} Logout recorded for ${badgeNumber} — session: ${sessionDurationMinutes}m`);
        return res.status(200).json({ 
            success: true, 
            message: 'Logout recorded', 
            sessionDurationMinutes 
        });

    } catch (err) {
        console.error(`${tag} Error:`, err.message);
        return res.status(500).json({ success: false, message: 'Internal Server Error', error: err.message });
    }
};

/**
 * @route   GET /api/officer/sessions
 * @desc    Retrieves officer session history with filtering and pagination.
 */
const getOfficerSessions = async (req, res) => {
    const { badgeNumber, startDate, endDate, page = 1, limit = 20 } = req.query;
    const filter = {};

    if (badgeNumber) filter.badgeNumber = badgeNumber;
    if (startDate && endDate) {
        filter.loginTime = { 
            $gte: new Date(startDate), 
            $lte: new Date(endDate) 
        };
    }

    try {
        const skip = (parseInt(page) - 1) * parseInt(limit);
        const [sessions, total] = await Promise.all([
            OfficerSession.find(filter).sort({ loginTime: -1 }).skip(skip).limit(parseInt(limit)),
            OfficerSession.countDocuments(filter)
        ]);

        return res.status(200).json({ 
            success: true, 
            data: sessions, 
            total, 
            page: parseInt(page), 
            pages: Math.ceil(total / parseInt(limit)) 
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: 'Server Error', error: err.message });
    }
};

/**
 * @route   GET /api/officer/sessions/last/:badgeNumber
 * @desc    Retrieves the most recent session info and grace window status.
 */
const getOfficerLastSession = async (req, res) => {
    const { badgeNumber } = req.params;

    try {
        const officer = await Police.findOne({ badgeNumber })
            .select('name badgeNumber isActive lastLoginTime lastLoginLocation lastLogoutTime fcmToken');
        
        if (!officer) {
            return res.status(404).json({ success: false, message: 'Officer not found' });
        }

        const lastSession = await OfficerSession.findOne({ badgeNumber })
            .sort({ loginTime: -1 });

        let graceWindowMinutes = 20;
        try {
            const SystemConfig = require('../models/systemConfigModel');
            const config = await SystemConfig.findOne();
            if (config && config.officerLogoutGracePeriodMinutes) {
                graceWindowMinutes = config.officerLogoutGracePeriodMinutes;
            }
        } catch (err) {
            console.warn('[OfficerSession] WARNING: Failed to fetch SystemConfig, using default grace period');
        }

        const graceWindowActive = (() => {
            if (officer.isActive) return false;
            if (!officer.lastLogoutTime) return false;
            const minutesSinceLogout = (Date.now() - officer.lastLogoutTime.getTime()) / 60000;
            return minutesSinceLogout <= graceWindowMinutes;
        })();

        return res.status(200).json({
            success: true,
            data: {
                officer: {
                    name: officer.name,
                    badgeNumber: officer.badgeNumber,
                    isActive: officer.isActive,
                    lastLoginTime: officer.lastLoginTime,
                    lastLogoutTime: officer.lastLogoutTime,
                    lastLoginLocation: officer.lastLoginLocation,
                    graceWindowActive
                },
                lastSession
            }
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: 'Server Error', error: err.message });
    }
};

module.exports = { officerLogout, getOfficerSessions, getOfficerLastSession };
