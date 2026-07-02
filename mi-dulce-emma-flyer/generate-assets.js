const QRCode = require('qrcode');
const path = require('path');

async function main() {
  await QRCode.toFile(
    path.join(__dirname, 'assets', 'qr-instagram.png'),
    'https://www.instagram.com/_mi_dulce_emma/',
    {
      width: 400,
      margin: 1,
      color: { dark: '#3d6b4f', light: '#ffffff' },
    }
  );
  console.log('QR generado: assets/qr-instagram.png');
}

main().catch(console.error);
