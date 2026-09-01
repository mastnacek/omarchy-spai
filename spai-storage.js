// spai-storage.js - Native SPAI Markdown File Storage Manager for Omarchy & pi-spai

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const SPAI_BASE_DIR = path.join(HOME, 'Documents', 'spai');
const SUBDIRS = {
  Todo: path.join(SPAI_BASE_DIR, 'tasks'),
  Note: path.join(SPAI_BASE_DIR, 'notes'),
  Idea: path.join(SPAI_BASE_DIR, 'ideas')
};
const INDEX_PATH = path.join(SPAI_BASE_DIR, '.index.json');

function ensureDirectories() {
  if (!fs.existsSync(SPAI_BASE_DIR)) fs.mkdirSync(SPAI_BASE_DIR, { recursive: true });
  for (const key of Object.keys(SUBDIRS)) {
    if (!fs.existsSync(SUBDIRS[key])) fs.mkdirSync(SUBDIRS[key], { recursive: true });
  }
}

function slugify(text) {
  return (text || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, '')
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 50) || 'item';
}

function formatDateTime(dateInput) {
  const pad = (n) => n.toString().padStart(2, '0');
  const d = dateInput ? new Date(dateInput) : new Date();
  if (isNaN(d.getTime())) return formatDateTime(new Date());
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

function getSubdirForType(type) {
  if (type === 'Note') return SUBDIRS.Note;
  if (type === 'Idea') return SUBDIRS.Idea;
  return SUBDIRS.Todo;
}

function formatMarkdown(record) {
  const lines = [
    '---',
    `type: ${record.type || 'Todo'}`,
    `title: "${(record.title || '').replace(/"/g, '\\"')}"`,
    `timestamp: ${record.timestamp || formatDateTime()}`,
    `status: ${record.status || 'todo'}`,
    'source: omarchy-spai'
  ];

  if (record.tags && record.tags.length > 0) {
    lines.push(`tags: [${record.tags.join(', ')}]`);
  }

  if (record.priority || record.deadline) {
    lines.push('facets:');
    if (record.priority) lines.push(`  priority: ${record.priority}`);
    if (record.deadline) lines.push(`  deadline: ${record.deadline}`);
  }

  if (record.symbol) {
    lines.push(`spai_symbol: '${record.symbol}'`);
  }

  lines.push('---');
  lines.push('');
  lines.push(`# ${record.id}: ${record.title}`);
  lines.push('');
  lines.push((record.raw || record.body || record.title || '').trim());
  lines.push('');

  return lines.join('\n');
}

function parseMarkdownFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const fileName = path.basename(filePath);
    let yamlRaw = '';
    let body = content;

    if (content.startsWith('---\n') || content.startsWith('---\r\n')) {
      const endFm = content.indexOf('\n---', 4);
      if (endFm !== -1) {
        yamlRaw = content.slice(4, endFm).trim();
        body = content.slice(endFm + 4).trimStart();
      }
    }

    const titleMatch = body.match(/^#\s*(SPAI-\d+)?:\s*(.+)$/m) || body.match(/^#\s*(.+)$/m);
    let id = 'SPAI-001';
    let title = 'Untitled';

    if (titleMatch) {
      if (titleMatch[1]) id = titleMatch[1].trim();
      if (titleMatch[2]) title = titleMatch[2].trim();
      else if (titleMatch[1]) title = titleMatch[1].trim();
    }

    let type = 'Todo';
    let status = 'todo';
    let timestamp = formatDateTime();
    let priority = 'normal';
    let deadline = '';
    let tags = [];
    let symbol = '.';

    if (yamlRaw) {
      const typeM = yamlRaw.match(/^type:\s*(.+)$/m);
      if (typeM) type = typeM[1].trim();

      const statusM = yamlRaw.match(/^status:\s*(.+)$/m);
      if (statusM) status = statusM[1].trim();

      const timeM = yamlRaw.match(/^timestamp:\s*(.+)$/m);
      if (timeM) timestamp = timeM[1].trim();

      const tagsM = yamlRaw.match(/^tags:\s*\[(.*)\]/m);
      if (tagsM) {
        tags = tagsM[1].split(',').map(t => t.trim().toLowerCase()).filter(Boolean);
      }

      const prioM = yamlRaw.match(/priority:\s*(.+)$/m);
      if (prioM) priority = prioM[1].trim();

      const deadM = yamlRaw.match(/deadline:\s*(.+)$/m);
      if (deadM) deadline = deadM[1].trim();

      const symM = yamlRaw.match(/spai_symbol:\s*'(.+)'/m);
      if (symM) symbol = symM[1].trim();
    }

    const cleanBody = body.replace(/^#\s*.+$/m, '').trim();

    return {
      id,
      title,
      type,
      status,
      symbol,
      timestamp,
      tags,
      priority,
      deadline,
      file: fileName,
      filePath,
      raw: cleanBody,
      body: cleanBody
    };
  } catch (err) {
    void err;
    return null;
  }
}

function loadAllRecords() {
  ensureDirectories();
  const records = [];

  for (const key of Object.keys(SUBDIRS)) {
    const dir = SUBDIRS[key];
    if (!fs.existsSync(dir)) continue;
    const files = fs.readdirSync(dir);
    for (const f of files) {
      if (f.endsWith('.md') && !f.startsWith('.')) {
        const p = path.join(dir, f);
        const parsed = parseMarkdownFile(p);
        if (parsed) records.push(parsed);
      }
    }
  }

  // Also check top-level SPAI_BASE_DIR for standalone .md files if any
  const topFiles = fs.readdirSync(SPAI_BASE_DIR);
  for (const f of topFiles) {
    if (f.endsWith('.md') && !f.startsWith('.')) {
      const p = path.join(SPAI_BASE_DIR, f);
      const parsed = parseMarkdownFile(p);
      if (parsed) records.push(parsed);
    }
  }

  records.sort((a, b) => {
    const numA = parseInt((a.id || '').replace(/\D/g, ''), 10) || 0;
    const numB = parseInt((b.id || '').replace(/\D/g, ''), 10) || 0;
    return numA - numB;
  });

  return records;
}

function getNextId(records) {
  let maxNum = 0;
  for (const r of records) {
    const match = (r.id || '').match(/^SPAI-(\d+)$/i);
    if (match) {
      const num = parseInt(match[1], 10);
      if (!isNaN(num) && num > maxNum) maxNum = num;
    }
  }
  return `SPAI-${(maxNum + 1).toString().padStart(3, '0')}`;
}

function writeIndexJson(records) {
  ensureDirectories();
  const data = {
    version: 1,
    lastUpdated: formatDateTime(),
    items: records || [],
    records: records || []
  };
  fs.writeFileSync(INDEX_PATH, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

function syncItem(item) {
  ensureDirectories();
  const records = loadAllRecords();
  
  if (!item.id || !item.id.startsWith('SPAI-')) {
    item.id = getNextId(records);
  }
  if (!item.timestamp) {
    item.timestamp = formatDateTime();
  }

  const datePrefix = (item.timestamp || formatDateTime()).split(' ')[0] || '2026-09-01';
  const slug = slugify(item.title) || 'item';
  const fileName = `${datePrefix}-${item.id}-${slug}.md`;
  const targetDir = getSubdirForType(item.type);
  const targetFilePath = path.join(targetDir, fileName);

  // Find existing file on disk across all subdirs to move or update
  let existingPath = null;
  for (const key of Object.keys(SUBDIRS)) {
    const d = SUBDIRS[key];
    const files = fs.existsSync(d) ? fs.readdirSync(d) : [];
    for (const f of files) {
      if (f.includes(item.id)) {
        existingPath = path.join(d, f);
        break;
      }
    }
    if (existingPath) break;
  }

  // If type changed or file moved: delete old file
  if (existingPath && existingPath !== targetFilePath) {
    try { fs.unlinkSync(existingPath); } catch (err) { void err; }
  }

  // Write markdown with frontmatter
  item.file = fileName;
  const mdContent = formatMarkdown(item);
  fs.writeFileSync(targetFilePath, mdContent, 'utf8');

  // Re-read all and save index
  const updatedRecords = loadAllRecords();
  writeIndexJson(updatedRecords);

  return item;
}

function deleteItemFile(id) {
  ensureDirectories();
  for (const key of Object.keys(SUBDIRS)) {
    const d = SUBDIRS[key];
    const files = fs.existsSync(d) ? fs.readdirSync(d) : [];
    for (const f of files) {
      if (f.includes(id)) {
        try { fs.unlinkSync(path.join(d, f)); } catch (err) { void err; }
      }
    }
  }

  const updatedRecords = loadAllRecords();
  writeIndexJson(updatedRecords);
}

function rebuildAll() {
  ensureDirectories();
  const records = loadAllRecords();
  writeIndexJson(records);
  return records;
}

// CLI actions
if (require.main === module) {
  const action = process.argv[2];
  if (action === 'rebuild') {
    const recs = rebuildAll();
    console.log(`Rebuilt SPAI index: ${recs.length} items in ~/Documents/spai/`);
  } else if (action === 'sync') {
    const inputJson = process.argv[3];
    if (inputJson) {
      try {
        const item = JSON.parse(inputJson);
        const res = syncItem(item);
        console.log(JSON.stringify(res));
      } catch (e) {
        console.error('Failed to parse input item:', e.message);
      }
    }
  } else if (action === 'delete') {
    const id = process.argv[3];
    if (id) deleteItemFile(id);
  }
}

module.exports = {
  SPAI_BASE_DIR,
  SUBDIRS,
  INDEX_PATH,
  loadAllRecords,
  syncItem,
  deleteItemFile,
  rebuildAll
};
