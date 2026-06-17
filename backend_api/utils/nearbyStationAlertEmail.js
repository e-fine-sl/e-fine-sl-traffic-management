/**
 * Email template for notifying nearby police stations about an accident.
 * Sent automatically when an accident is reported within 10km of a station.
 */

const buildNearbyStationAlertHtml = ({
  stationName,
  stationCode,
  distanceKm,
  driverName,
  licenseNumber,
  driverPhone,
  accidentType,
  description,
  latitude,
  longitude,
  mapsLink,
  province,
  district,
  division,
  reportedAt
}) => {
  return `
    <div style="max-width: 600px; margin: 0 auto; font-family: 'Segoe UI', Arial, sans-serif; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
      
      <!-- Header -->
      <div style="background: linear-gradient(135deg, #b71c1c 0%, #d32f2f 50%, #e53935 100%); padding: 24px; text-align: center; color: white;">
        <h1 style="margin: 0; font-size: 26px; letter-spacing: 1px;">⚠️ EMERGENCY ALERT</h1>
        <p style="margin: 8px 0 0 0; font-size: 13px; opacity: 0.9;">e-Fine SL — Automated Accident Notification</p>
      </div>

      <!-- Station Info Banner -->
      <div style="background-color: #fff3e0; padding: 16px 20px; border-bottom: 2px solid #ffcc80; display: flex; align-items: center;">
        <div style="text-align: center; width: 100%;">
          <p style="margin: 0; font-size: 14px; color: #e65100; font-weight: bold;">
            🏢 ${stationName} (${stationCode})
          </p>
          <p style="margin: 4px 0 0 0; font-size: 13px; color: #bf360c;">
            An accident has been reported <strong>${distanceKm} km</strong> from your station
          </p>
        </div>
      </div>

      <!-- Accident Type -->
      <div style="background-color: #ffebee; padding: 16px; text-align: center; border-bottom: 1px solid #ef9a9a;">
        <h2 style="color: #c62828; margin: 0; font-size: 22px;">${accidentType}</h2>
        <p style="color: #b71c1c; margin: 6px 0 0 0; font-size: 13px;">Reported at: ${reportedAt}</p>
      </div>

      <!-- Content -->
      <div style="padding: 24px;">
        
        <!-- Driver Details -->
        <h3 style="color: #333; margin: 0 0 12px 0; border-bottom: 2px solid #eee; padding-bottom: 8px; font-size: 15px;">
          👤 Driver Details
        </h3>
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px;">
          <tr>
            <td style="padding: 10px 0; color: #666; width: 40%; font-size: 14px;">Name:</td>
            <td style="padding: 10px 0; font-weight: bold; color: #333; font-size: 14px;">${driverName}</td>
          </tr>
          <tr style="background-color: #fafafa;">
            <td style="padding: 10px 0; color: #666; font-size: 14px;">License Number:</td>
            <td style="padding: 10px 0; font-weight: bold; color: #333; font-size: 14px;">${licenseNumber}</td>
          </tr>
          <tr>
            <td style="padding: 10px 0; color: #666; font-size: 14px;">Phone:</td>
            <td style="padding: 10px 0; font-weight: bold; color: #333; font-size: 14px;">${driverPhone || 'Not provided'}</td>
          </tr>
        </table>

        <!-- Location Details -->
        <h3 style="color: #333; margin: 0 0 12px 0; border-bottom: 2px solid #eee; padding-bottom: 8px; font-size: 15px;">
          📍 Accident Location
        </h3>
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px;">
          <tr>
            <td style="padding: 10px 0; color: #666; width: 40%; font-size: 14px;">Province:</td>
            <td style="padding: 10px 0; font-weight: bold; color: #333; font-size: 14px;">${province}</td>
          </tr>
          <tr style="background-color: #fafafa;">
            <td style="padding: 10px 0; color: #666; font-size: 14px;">District:</td>
            <td style="padding: 10px 0; font-weight: bold; color: #333; font-size: 14px;">${district}</td>
          </tr>
          <tr>
            <td style="padding: 10px 0; color: #666; font-size: 14px;">Police Division:</td>
            <td style="padding: 10px 0; font-weight: bold; color: #333; font-size: 14px;">${division}</td>
          </tr>
          <tr style="background-color: #fafafa;">
            <td style="padding: 10px 0; color: #666; font-size: 14px;">GPS Coordinates:</td>
            <td style="padding: 10px 0; font-weight: bold; color: #1565c0; font-size: 14px;">${latitude}, ${longitude}</td>
          </tr>
        </table>

        <!-- Map Link -->
        <div style="text-align: center; margin: 28px 0;">
          <a href="${mapsLink}" target="_blank" 
             style="background: linear-gradient(135deg, #c62828, #d32f2f); color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block; font-size: 15px; box-shadow: 0 2px 8px rgba(211,47,47,0.3);">
            🗺️ View Accident on Google Maps
          </a>
        </div>

        ${description ? `
        <!-- Description -->
        <div style="background-color: #fff8e1; border: 1px solid #ffecb3; padding: 16px; border-radius: 6px; margin-bottom: 20px;">
          <h4 style="color: #f57f17; margin: 0 0 8px 0; font-size: 14px;">📝 Driver's Description</h4>
          <p style="color: #333; margin: 0; font-size: 14px; line-height: 1.6;">${description}</p>
        </div>
        ` : ''}

        <!-- Urgent Notice -->
        <div style="background-color: #fce4ec; border-left: 4px solid #c62828; padding: 14px 16px; border-radius: 0 6px 6px 0; margin-top: 20px;">
          <p style="margin: 0; color: #b71c1c; font-size: 13px; font-weight: bold;">
            ⚡ IMMEDIATE ACTION REQUIRED
          </p>
          <p style="margin: 6px 0 0 0; color: #c62828; font-size: 13px; line-height: 1.5;">
            Please dispatch officers to the accident location immediately. The driver may require emergency assistance.
          </p>
        </div>
      </div>

      <!-- Footer -->
      <div style="background-color: #f5f5f5; padding: 16px; text-align: center; border-top: 1px solid #e0e0e0;">
        <p style="margin: 0 0 4px 0; color: #757575; font-size: 12px;">
          This is an automated emergency alert from e-Fine SL Traffic Management System.
        </p>
        <p style="margin: 0; color: #9e9e9e; font-size: 11px;">
          Do not reply to this email. For system queries contact the admin portal.
        </p>
      </div>
    </div>
  `;
};

module.exports = { buildNearbyStationAlertHtml };
