// utils/cryptoService.js (Main Backend)
// RSA decryption for register and password-reset flows.
// Flutter encrypts passwords with RSA public key BEFORE sending.
// This utility decrypts them using the private key stored in .env.

const forge = require('node-forge');

/**
 * Decrypts an RSA-OAEP (SHA-1) base64-encoded password.
 * @param {string} encryptedBase64 - received from Flutter
 * @returns {string} plain-text password
 */
const decryptPassword = (encryptedBase64) => {
  const privateKeyPem = process.env.RSA_PRIVATE_KEY;
  if (!privateKeyPem) {
    throw new Error('RSA_PRIVATE_KEY not configured in environment');
  }

  // Restore newlines if stored with literal \n in .env
  const formattedKey = privateKeyPem.replace(/\\n/g, '\n');
  const privateKey   = forge.pki.privateKeyFromPem(formattedKey);
  const encryptedBytes = forge.util.decode64(encryptedBase64);

  // Decrypt with OAEP (matches Flutter pointycastle OAEPEncoding)
  return privateKey.decrypt(encryptedBytes, 'RSA-OAEP');
};

/**
 * Returns the RSA public key in PEM format, derived from the private key in .env.
 * Flutter fetches this to encrypt passwords before sending.
 * @returns {string} public key PEM
 */
const getPublicKeyPem = () => {
  const privateKeyPem = process.env.RSA_PRIVATE_KEY;
  if (!privateKeyPem) {
    throw new Error('RSA_PRIVATE_KEY not configured in environment');
  }
  const formattedKey = privateKeyPem.replace(/\\n/g, '\n');
  const privateKey   = forge.pki.privateKeyFromPem(formattedKey);
  const publicKey    = forge.pki.rsa.setPublicKey(privateKey.n, privateKey.e);
  return forge.pki.publicKeyToPem(publicKey);
};

module.exports = { decryptPassword, getPublicKeyPem };
