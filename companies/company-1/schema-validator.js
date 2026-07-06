/**
 * schema-validator.js – حارس دستور الروائع
 * يفحص جميع ملفات المشروع ويمنع أي مخالفة للدستور
 * 
 * الاستخدام:
 *   node schema-validator.js [مجلد المشروع]
 * 
 * الخروج:
 *   0 = لا توجد مخالفات
 *   1 = توجد مخالفات (يمنع النشر)
 */

var fs = require('fs');
var path = require('path');

// ============================================================
// قائمة المخالفات التي نبحث عنها
// ============================================================
var RULES = [
    {
        id: 'ES5-01',
        pattern: /\bconst\b/,
        message: 'استخدام const – استخدم var فقط'
    },
    {
        id: 'ES5-02',
        pattern: /\blet\b/,
        message: 'استخدام let – استخدم var فقط'
    },
    {
        id: 'ES5-03',
        pattern: /\(\)\s*=>/,
        message: 'Arrow Function () => – استخدم function() {}'
    },
    {
        id: 'ES5-04',
        pattern: /\.find\s*\(/,
        message: 'Array.find – استخدم حلقة for للبحث'
    },
    {
        id: 'INVOKE-01',
        pattern: /supabase\.functions\.invoke/,
        message: 'supabase.functions.invoke – استخدم fetch اليدوي مع Authorization: Bearer'
    },
    {
        id: 'SCHEMA-01',
        pattern: /run_sheet_details.*notes/,
        message: 'افتراض وجود عمود notes في run_sheet_details – العمود غير موجود'
    },
    {
        id: 'ES5-05',
        pattern: /onclick="[^"]*\$\{[^}]*\}[^"]*"/,
        message: 'Template Literals داخل onclick – استخدم دمج النصوص +'
    },
    {
        id: 'ES5-06',
        pattern: /\bconst\s*\{/,
        message: 'Destructuring محظور – استخدم var = object.property'
    }
];

// ============================================================
// المجلدات التي نفحصها
// ============================================================
var SCAN_DIRECTORIES = [
    'companies',
    'supabase/functions'
];

// ============================================================
// امتدادات الملفات التي نفحصها
// ============================================================
var SCAN_EXTENSIONS = ['.html', '.js', '.ts'];

// ============================================================
// المجلدات المستثناة من الفحص
// ============================================================
var EXCLUDED_DIRS = ['node_modules', '.git', '.supabase'];

// ============================================================
// دالة مساعدة: هل الملف امتداده ضمن القائمة؟
// ============================================================
function isScannable(filePath) {
    var ext = path.extname(filePath).toLowerCase();
    for (var i = 0; i < SCAN_EXTENSIONS.length; i++) {
        if (ext === SCAN_EXTENSIONS[i]) {
            return true;
        }
    }
    return false;
}

// ============================================================
// دالة مساعدة: هل المجلد مستثنى؟
// ============================================================
function isExcludedDir(dirName) {
    for (var i = 0; i < EXCLUDED_DIRS.length; i++) {
        if (dirName === EXCLUDED_DIRS[i]) {
            return true;
        }
    }
    return false;
}

// ============================================================
// دالة: فحص ملف واحد
// ============================================================
function scanFile(filePath) {
    var violations = [];
    
    try {
        var content = fs.readFileSync(filePath, 'utf-8');
        var lines = content.split('\n');
        
        for (var i = 0; i < RULES.length; i++) {
            var rule = RULES[i];
            
            for (var lineNum = 0; lineNum < lines.length; lineNum++) {
                var line = lines[lineNum];
                
                if (rule.pattern.test(line)) {
                    violations.push({
                        ruleId: rule.id,
                        message: rule.message,
                        file: filePath,
                        line: lineNum + 1,
                        snippet: line.trim().substring(0, 120)
                    });
                }
            }
        }
    } catch (err) {
        violations.push({
            ruleId: 'READ-ERROR',
            message: 'تعذر قراءة الملف: ' + err.message,
            file: filePath,
            line: 0,
            snippet: ''
        });
    }
    
    return violations;
}

// ============================================================
// دالة: فحص مجلد ومجلداته الفرعية
// ============================================================
function scanDirectory(dirPath) {
    var allViolations = [];
    var fileCount = 0;
    
    try {
        var entries = fs.readdirSync(dirPath);
        
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var fullPath = path.join(dirPath, entry);
            
            try {
                var stat = fs.statSync(fullPath);
                
                if (stat.isDirectory()) {
                    if (!isExcludedDir(entry)) {
                        var subViolations = scanDirectory(fullPath);
                        allViolations = allViolations.concat(subViolations.violations);
                        fileCount += subViolations.fileCount;
                    }
                } else if (stat.isFile() && isScannable(fullPath)) {
                    fileCount++;
                    var fileViolations = scanFile(fullPath);
                    allViolations = allViolations.concat(fileViolations);
                }
            } catch (e) {
                // تخطي الملفات/المجلدات التي لا نستطيع قراءتها
            }
        }
    } catch (err) {
        console.log('تحذير: تعذر فحص المجلد: ' + dirPath + ' (' + err.message + ')');
    }
    
    return { violations: allViolations, fileCount: fileCount };
}

// ============================================================
// الدالة الرئيسية
// ============================================================
function main() {
    var projectRoot = process.argv[2] || '.';
    
    console.log('');
    console.log('🛡️  ====================================');
    console.log('🛡️  حارس دستور الروائع – Schema Validator');
    console.log('🛡️  ====================================');
    console.log('');
    console.log('📂 جاري فحص المجلد: ' + path.resolve(projectRoot));
    console.log('');
    
    var totalViolations = [];
    var totalFiles = 0;
    
    for (var d = 0; d < SCAN_DIRECTORIES.length; d++) {
        var dirPath = path.join(projectRoot, SCAN_DIRECTORIES[d]);
        
        if (fs.existsSync(dirPath)) {
            var result = scanDirectory(dirPath);
            totalViolations = totalViolations.concat(result.violations);
            totalFiles += result.fileCount;
        }
    }
    
    // عرض النتائج
    if (totalViolations.length === 0) {
        console.log('✅  تم فحص ' + totalFiles + ' ملف.');
        console.log('✅  لا توجد أي مخالفات للدستور.');
        console.log('✅  النظام جاهز للنشر.');
        console.log('');
        process.exit(0);
    } else {
        // تجميع المخالفات حسب القاعدة
        var ruleCounts = {};
        for (var v = 0; v < totalViolations.length; v++) {
            var ruleId = totalViolations[v].ruleId;
            if (!ruleCounts[ruleId]) {
                ruleCounts[ruleId] = { count: 0, message: totalViolations[v].message };
            }
            ruleCounts[ruleId].count++;
        }
        
        console.log('❌  ====================================');
        console.log('❌  تم العثور على ' + totalViolations.length + ' مخالفة للدستور');
        console.log('❌  ====================================');
        console.log('');
        
        console.log('📊  ملخص المخالفات:');
        console.log('');
        
        for (var ruleId in ruleCounts) {
            if (ruleCounts.hasOwnProperty(ruleId)) {
                var rc = ruleCounts[ruleId];
                console.log('   [' + ruleId + '] ' + rc.message + ' – ' + rc.count + ' مرة');
            }
        }
        
        console.log('');
        console.log('📋  تفاصيل المخالفات:');
        console.log('');
        
        for (var w = 0; w < totalViolations.length; w++) {
            var viol = totalViolations[w];
            console.log('   📄 ' + viol.file + ' (سطر ' + viol.line + ')');
            console.log('      [' + viol.ruleId + '] ' + viol.message);
            console.log('      ```' + viol.snippet + '```');
            console.log('');
        }
        
        console.log('⛔  النشر ممنوع حتى إصلاح جميع المخالفات.');
        console.log('');
        process.exit(1);
    }
}

// ============================================================
// بدء التنفيذ
// ============================================================
main();
