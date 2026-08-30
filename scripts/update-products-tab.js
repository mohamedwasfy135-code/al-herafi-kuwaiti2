const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '..', 'src', 'components', 'dashboard', 'products-tab.tsx');
let content = fs.readFileSync(filePath, 'utf8');

// 1. إضافة متغير الحالة globalCategories بعد suppliers
content = content.replace(
  /const \[suppliers, setSuppliers\] = useState<Supplier\[\]>\(\[\]\)/,
  `const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [globalCategories, setGlobalCategories] = useState<any[]>([])`
);

// 2. داخل دالة fetchProducts، بعد setSuppliers نضيف جلب الفئات العامة
// نبحث عن الكتلة التي تحدث setSuppliers ونضيف بعدها
content = content.replace(
  /setSuppliers\(data\.map\(\(s: any\) => \({ id: s\.id, name: s\.name }\)\)\)/,
  `setSuppliers(data.map((s: any) => ({ id: s.id, name: s.name })))
      // جلب الفئات العامة (فئات المحلات) للاختيار
      try {
        const globalCatRes = await fetch('/api/categories?type=shop,contractor,company,consultant');
        if (globalCatRes.ok) {
          const globalData = await globalCatRes.json();
          const cats = Array.isArray(globalData) ? globalData : (globalData.categories || []);
          setGlobalCategories(cats);
        }
      } catch (e) { console.error('Failed to fetch global categories', e) }`
);

// 3. تعديل قائمة اختيار الفئة: نضيف الفئات العامة بعد الفئات المحلية (أو نستبدلها)
// نبحث عن <SelectContent> داخل حوار المنتج ونضيف globalCategories.map
// سنجد المقطع الذي يحتوي على productCategories.map ونضيف قبله globalCategories
content = content.replace(
  /(\{productCategories\.map\(\(cat\) => \(\s*<SelectItem key=\{cat\.id\} value=\{String\(cat\.id\)\}>\{cat\.name\}<\/SelectItem>\s*\)\)\})/,
  `{globalCategories.map((cat) => (
                <SelectItem key={cat.id} value={String(cat.id)}>{cat.name}</SelectItem>
              ))}
              $1`
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('✅ تم تحديث ProductsTab بنجاح');
