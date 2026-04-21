const fs = require('fs');
const path = require('path');

const files = [
  'lib/screens/police/police_home_screen.dart',
  'lib/screens/police/new_fine.dart',
  'lib/screens/police/fine_history_screen.dart',
  'lib/screens/police/profile_screen.dart'
];

for (const file of files) {
  const filePath = path.join(__dirname, file);
  if (fs.existsSync(filePath)) {
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Replace import
    // Note: if it has hide TextDirection, handle it
    content = content.replace(/import 'package:easy_localization\/easy_localization\.dart'.*;/g, 
      "import '../../services/police_locale_service.dart';\nimport '../../widgets/police/police_text.dart';");
      
    // Replace Text('key'.tr()) with PoliceText('key')
    content = content.replace(/Text\(\s*'([^']+)'\.tr\(\)/g, "PoliceText('$1'");
    
    // Replace 'key'.tr() with PoliceLocaleService.instance.translate('key')
    content = content.replace(/'([^']+)'\.tr\(\)/g, "PoliceLocaleService.instance.translate('$1')");
    
    fs.writeFileSync(filePath, content);
    console.log(`Migrated ${file}`);
  } else {
    console.log(`File not found: ${file}`);
  }
}
