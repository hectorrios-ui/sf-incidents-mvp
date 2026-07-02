const QRCode = require('qrcode');
const fs = require('fs');
const path = require('path');

const assetsDir = path.join(__dirname, 'assets');

async function main() {
  await QRCode.toFile(
    path.join(assetsDir, 'qr-instagram.png'),
    'https://www.instagram.com/_mi_dulce_emma/',
    {
      width: 400,
      margin: 1,
      color: { dark: '#2d5a3d', light: '#ffffff' },
    }
  );

  const logoSvg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">
  <defs>
    <clipPath id="circle"><circle cx="100" cy="100" r="88"/></clipPath>
  </defs>
  <circle cx="100" cy="100" r="96" fill="none" stroke="#f4a5b8" stroke-width="6"/>
  <circle cx="100" cy="100" r="88" fill="none" stroke="#f9d56e" stroke-width="5"/>
  <circle cx="100" cy="100" r="80" fill="none" stroke="#8bc48a" stroke-width="5"/>
  <circle cx="100" cy="100" r="72" fill="none" stroke="#7ec8e3" stroke-width="4"/>
  <circle cx="100" cy="100" r="64" fill="#fffef8"/>
  <g clip-path="url(#circle)">
    <ellipse cx="100" cy="130" rx="42" ry="28" fill="#f9e4c8"/>
    <circle cx="78" cy="88" r="18" fill="#5c3d2e"/>
    <circle cx="122" cy="92" r="14" fill="#5c3d2e"/>
    <ellipse cx="78" cy="95" rx="20" ry="24" fill="#f5d0b5"/>
    <ellipse cx="122" cy="98" rx="16" ry="20" fill="#f5d0b5"/>
    <path d="M70 78 Q78 55 95 62 Q100 48 108 58 Q125 52 130 75" fill="#5c3d2e"/>
    <path d="M108 58 Q115 45 128 55 Q138 70 130 85" fill="#5c3d2e"/>
    <ellipse cx="100" cy="118" rx="22" ry="16" fill="#f5d0b5"/>
    <circle cx="94" cy="114" r="2" fill="#4a3728"/>
    <circle cx="106" cy="114" r="2" fill="#4a3728"/>
    <path d="M96 122 Q100 126 104 122" fill="none" stroke="#d4846a" stroke-width="1.5"/>
    <path d="M88 108 Q100 100 112 108" fill="none" stroke="#5c3d2e" stroke-width="3" stroke-linecap="round"/>
  </g>
  <text x="100" y="28" text-anchor="middle" font-family="Georgia, serif" font-size="13" font-weight="bold" fill="#5c3d2e">Mi Dulce Emma</text>
  <text x="100" y="182" text-anchor="middle" font-family="Georgia, serif" font-size="9" fill="#5c3d2e">Crecer Jugando</text>
</svg>`;

  fs.writeFileSync(path.join(assetsDir, 'logo.svg'), logoSvg);
  console.log('Assets generated: qr-instagram.png, logo.svg');
}

main().catch(console.error);
