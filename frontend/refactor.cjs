const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname, 'src');

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(function(file) {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) { 
            results = results.concat(walk(file));
        } else { 
            if (file.endsWith('.vue')) results.push(file);
        }
    });
    return results;
}

const vueFiles = walk(srcDir);

const replacements = [
    // Backgrounds
    { regex: /bg-\[#0d0e12\]/g, replace: 'bg-canvas' },
    { regex: /bg-\[#161920\](\/[0-9]+)?/g, replace: 'bg-surface-1' },
    { regex: /bg-\[#1b1f28\](\/[0-9]+)?/g, replace: 'bg-surface-2' },
    { regex: /bg-\[#1c2230\](\/[0-9]+)?/g, replace: 'bg-surface-2' },
    { regex: /bg-\[#1a1e28\](\/[0-9]+)?/g, replace: 'bg-surface-2' },
    { regex: /bg-\[#1f2430\](\/[0-9]+)?/g, replace: 'bg-surface-3' },
    { regex: /bg-gradient-to-[a-z]+ from-\[#161920\] to-\[#[a-z0-9]+\]/g, replace: 'bg-surface-1' },
    
    // Borders
    { regex: /border-\[#262b35\](\/[0-9]+)?/g, replace: 'border-hairline' },
    { regex: /border-\[#2e3543\](\/[0-9]+)?/g, replace: 'border-hairline-strong' },
    { regex: /hover:border-\[#4facfe\](\/[0-9]+)?/g, replace: 'hover:border-primary' },
    { regex: /hover:border-\[#8c9ba5\]/g, replace: 'hover:border-ink-subtle' },
    
    // Text colors
    { regex: /text-white/g, replace: 'text-ink' },
    { regex: /text-\[#8c9ba5\]/g, replace: 'text-ink-subtle' },
    { regex: /text-\[#515c6e\]/g, replace: 'text-ink-tertiary' },
    { regex: /text-\[#00f2fe\]/g, replace: 'text-primary' },
    { regex: /text-green-400/g, replace: 'text-semantic-success' },
    { regex: /text-yellow-[0-9]+/g, replace: 'text-ink-muted' },
    { regex: /text-red-400/g, replace: 'text-ink-muted' },
    { regex: /text-red-500/g, replace: 'text-ink-muted' },

    // Primary Accents (Buttons, Gradients, etc)
    { regex: /bg-gradient-to-[a-z]+ from-\[#00f2fe\] to-\[#4facfe\]/g, replace: 'bg-primary' },
    { regex: /bg-gradient-to-[a-z]+ from-red-500 to-pink-600/g, replace: 'bg-surface-3 border border-hairline-strong' },
    { regex: /hover:from-\[#00d8e4\] hover:to-\[#3b93e6\]/g, replace: 'hover:bg-primary-hover' },
    { regex: /hover:from-red-600 hover:to-pink-700/g, replace: 'hover:bg-surface-4' },
    { regex: /bg-clip-text text-transparent/g, replace: 'text-primary' },
    
    // Semantic Backgrounds
    { regex: /bg-green-500\/10/g, replace: 'bg-surface-2' },
    { regex: /bg-red-500\/10/g, replace: 'bg-surface-2' },
    { regex: /bg-yellow-500\/10/g, replace: 'bg-surface-2' },
    { regex: /bg-\[#00f2fe\]\/10/g, replace: 'bg-primary-focus/10' },
    
    // Semantic Borders
    { regex: /border-green-500\/[0-9]+/g, replace: 'border-hairline' },
    { regex: /border-red-500\/[0-9]+/g, replace: 'border-hairline' },
    { regex: /border-yellow-500\/[0-9]+/g, replace: 'border-hairline' },
    { regex: /border-\[#00f2fe\]\/20/g, replace: 'border-primary' },

    // Shadows & Blurs & Neon
    { regex: /shadow-lg shadow-\[#4facfe\]\/[0-9]+/g, replace: 'shadow-none' },
    { regex: /hover:shadow-\[#4facfe\]\/[0-9]+/g, replace: 'shadow-none' },
    { regex: /shadow-\[.*?\]/g, replace: 'shadow-none' },
    { regex: /shadow-2xl/g, replace: 'shadow-none' },
    { regex: /shadow-xl/g, replace: 'shadow-none' },
    { regex: /shadow-lg/g, replace: 'shadow-none' },
    { regex: /backdrop-blur-xl/g, replace: '' },
    { regex: /backdrop-blur-sm/g, replace: '' },
    { regex: /backdrop-blur-md/g, replace: '' },
    { regex: /blur-3xl/g, replace: 'hidden' }, // hide neon blobs
    { regex: /animate-pulse/g, replace: '' },
    { regex: /bg-radial-gradient/g, replace: 'bg-canvas' },

    // Typography & Rounded Defaults (General mappings)
    { regex: /rounded-2xl/g, replace: 'rounded-xl' },
    { regex: /rounded-3xl/g, replace: 'rounded-xxl' },
    { regex: /rounded-xl/g, replace: 'rounded-lg' },
    { regex: /text-3xl/g, replace: 'text-display-md font-display' },
    { regex: /text-2xl/g, replace: 'text-headline font-display' },
    { regex: /text-xs/g, replace: 'text-caption' },
    { regex: /font-extrabold/g, replace: 'font-semibold' },
    { regex: /font-black/g, replace: 'font-semibold' },
    
    // Removing the explicit absolute decorative blobs
    { regex: /<div class="absolute.*?bg-\[#00f2fe\].*?><\/div>/g, replace: '' },
    { regex: /<div class="absolute.*?bg-\[#4facfe\].*?><\/div>/g, replace: '' },
];

vueFiles.forEach(file => {
    let content = fs.readFileSync(file, 'utf8');
    replacements.forEach(r => {
        content = content.replace(r.regex, r.replace);
    });
    fs.writeFileSync(file, content, 'utf8');
});

console.log("Refactoring complete.");
