const fs = require('fs');
const path = require('path');

const dir = path.resolve(__dirname, '..', 'docs', 'diagrams');
if (!fs.existsSync(dir)) {
  console.error('Directory does not exist:', dir);
  process.exit(1);
}

const files = fs.readdirSync(dir).filter((f) => f.endsWith('.svg'));
console.log(`Processing ${files.length} SVG diagram files...`);

files.forEach((f) => {
  const filePath = path.join(dir, f);
  let content = fs.readFileSync(filePath, 'utf8');

  if (!content.includes('id="svg-bg-canvas"')) {
    const match = content.match(/<svg[^>]*>/);
    if (match) {
      const svgTag = match[0];
      const newSvgTag = `${svgTag}\n<rect id="svg-bg-canvas" x="0" y="0" width="100%" height="100%" fill="#ffffff" style="fill:#ffffff;"/>`;
      content = content.replace(svgTag, newSvgTag);
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`✅ Added solid white canvas background to: ${f}`);
    }
  } else {
    console.log(`ℹ️ Already has canvas background: ${f}`);
  }
});

console.log('All SVG diagrams updated successfully with solid white backgrounds!');
