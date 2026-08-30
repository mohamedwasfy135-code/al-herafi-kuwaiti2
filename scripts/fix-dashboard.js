const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '..', 'src', 'app', 'dashboard', 'page.tsx');
let content = fs.readFileSync(filePath, 'utf8');

// استبدال المقطع الذي يحصل على allCats
content = content.replace(
  /const allCats = catData\.categories \|\| catData \|\| \[\]([\s\S]*?)setCategories\(allCats\.filter/m,
  `let allCats = catData.categories || catData || [];
  if (!Array.isArray(allCats)) allCats = [];
  setCategories(allCats.filter`
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('✅ تم إصلاح dashboard/page.tsx');
