// SpaiModel.js - Core SPAI Logic for Omarchy Plugin

function getSpaiPrefixes() {
  return [
    { prefix: "/. ", marker: "/.", type: "Todo", status: "waiting" },
    { prefix: ". ", marker: ".", type: "Todo", status: "todo" },
    { prefix: "/ ", marker: "/", type: "Todo", status: "working" },
    { prefix: "x ", marker: "x", type: "Todo", status: "done" },
    { prefix: "X ", marker: "X", type: "Todo", status: "done" },
    { prefix: "z ", marker: "z", type: "Todo", status: "cancelled" },
    { prefix: "Z ", marker: "Z", type: "Todo", status: "cancelled" },
    { prefix: "- ", marker: "-", type: "Note", status: "note" },
    { prefix: "? ", marker: "?", type: "Idea", status: "idea" },
  ];
}

function generateId() {
  return `spai_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
}

function parseRawItem(rawText) {
  const text = (rawText || "").trim();
  if (!text) return null;

  let type = "Todo";
  let status = "todo";
  let symbol = ".";
  let content = text;

  const prefixes = getSpaiPrefixes();
  for (let i = 0; i < prefixes.length; i++) {
    const def = prefixes[i];
    if (text.startsWith(def.prefix)) {
      type = def.type;
      status = def.status;
      symbol = def.marker;
      content = text.slice(def.prefix.length).trim();
      break;
    } else if (text === def.marker) {
      type = def.type;
      status = def.status;
      symbol = def.marker;
      content = "";
      break;
    } else if (text.startsWith(`${def.marker} `)) {
      type = def.type;
      status = def.status;
      symbol = def.marker;
      content = text.slice(def.marker.length + 1).trim();
      break;
    }
  }

  // Extract Priority `!`
  let priority = "normal";
  const prioMatch = /(?:^|\s)!(?:\s|$)/;
  if (prioMatch.test(content)) {
    priority = "high";
    content = content.replace(prioMatch, " ").trim();
  }

  // Extract Deadline `@today`, `@tomorrow`, `@YYYY-MM-DD`, `@DD.MM.` or `@DD.MM.YYYY`
  let deadline = "";
  const deadlineRe =
    /(?:^|\s)@(?:(today|dnes|tomorrow|zitra|zejtra)|(\d{4}-\d{2}-\d{2})|(\d{1,2}\.\d{1,2}\.(?:\d{4})?))(?:\s|$)/i;
  const deadMatch = content.match(deadlineRe);
  if (deadMatch) {
    if (deadMatch[1]) {
      const rel = deadMatch[1].toLowerCase();
      const now = new Date();
      if (rel === "tomorrow" || rel === "zitra" || rel === "zejtra") {
        now.setDate(now.getDate() + 1);
      }
      const y = now.getFullYear();
      const m = String(now.getMonth() + 1).padStart(2, "0");
      const d = String(now.getDate()).padStart(2, "0");
      deadline = `${y}-${m}-${d}`;
    } else if (deadMatch[2]) {
      deadline = deadMatch[2];
    } else if (deadMatch[3]) {
      const parts = deadMatch[3].split(".").filter(Boolean);
      const day = (parts[0] || "").padStart(2, "0");
      const month = (parts[1] || "").padStart(2, "0");
      const year = parts[2] || new Date().getFullYear().toString();
      deadline = `${year}-${month}-${day}`;
    }
    content = content.replace(deadlineRe, " ").trim();
  }

  // Extract Tags `:tag1:tag2:`
  const tags = [];
  const tagBlockRe =
    /(?:^|\s):([A-Za-z0-9_./-]+(?::[A-Za-z0-9_./-]+)*):(?:\s|$)/g;
  content = content
    .replace(tagBlockRe, (_m, tagChain) => {
      const split = tagChain.split(":").filter(Boolean);
      for (let k = 0; k < split.length; k++) {
        const t = split[k].toLowerCase();
        if (!tags.includes(t)) tags.push(t);
      }
      return " ";
    })
    .trim();

  return {
    id: generateId(),
    raw: rawText,
    type: type,
    status: status,
    symbol: symbol,
    title: content || text,
    priority: priority,
    deadline: deadline,
    tags: tags,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function parseItems(jsonString) {
  if (!jsonString) return [];
  try {
    const data = JSON.parse(jsonString);
    if (Array.isArray(data)) return data;
    if (data && Array.isArray(data.items)) return data.items;
    return [];
  } catch (err) {
    void err;
    return [];
  }
}

function formatItems(items) {
  return JSON.stringify(
    {
      version: 1,
      updatedAt: new Date().toISOString(),
      items: items || [],
    },
    null,
    2,
  );
}

function addItem(items, rawOrItem) {
  const list = (items || []).slice();
  const item =
    typeof rawOrItem === "string" ? parseRawItem(rawOrItem) : rawOrItem;
  if (!item) return list;
  list.unshift(item);
  return list;
}

function updateItem(items, id, updates) {
  const list = (items || []).slice();
  for (let i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      const old = list[i];
      const merged = Object.assign({}, old, updates, {
        updatedAt: new Date().toISOString(),
      });
      list[i] = merged;
      break;
    }
  }
  return list;
}

function removeItem(items, id) {
  return (items || []).filter((it) => it.id !== id);
}

function moveStatus(items, id, targetStatus) {
  const valid = [
    "todo",
    "working",
    "waiting",
    "done",
    "cancelled",
    "note",
    "idea",
  ];
  if (!valid.includes(targetStatus)) return items;

  let type = "Todo";
  let symbol = ".";
  if (targetStatus === "note") {
    type = "Note";
    symbol = "-";
  } else if (targetStatus === "idea") {
    type = "Idea";
    symbol = "?";
  } else if (targetStatus === "working") {
    symbol = "/";
  } else if (targetStatus === "waiting") {
    symbol = "/.";
  } else if (targetStatus === "done") {
    symbol = "x";
  } else if (targetStatus === "cancelled") {
    symbol = "z";
  }

  return updateItem(items, id, {
    status: targetStatus,
    type: type,
    symbol: symbol,
  });
}

function cycleStatus(items, id, direction) {
  const statuses = ["todo", "working", "waiting", "done", "cancelled"];
  const list = items || [];
  for (let i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      const current = list[i].status;
      let idx = statuses.indexOf(current);
      if (idx === -1) idx = 0;
      const nextIdx = (idx + direction + statuses.length) % statuses.length;
      return moveStatus(list, id, statuses[nextIdx]);
    }
  }
  return list;
}

function filterItems(items, filterText, typeFilter, statusFilter) {
  const list = items || [];
  const q = (filterText || "").toLowerCase().trim();

  return list.filter((it) => {
    if (typeFilter && it.type !== typeFilter) return false;
    if (statusFilter && it.status !== statusFilter) return false;

    if (!q) return true;

    if (it.title && it.title.toLowerCase().includes(q)) return true;
    if (it.deadline && it.deadline.includes(q)) return true;
    if (it.tags && it.tags.some((t) => t.includes(q))) return true;

    return false;
  });
}

function getStats(items) {
  const list = items || [];
  const stats = {
    total: list.length,
    todo: 0,
    working: 0,
    waiting: 0,
    done: 0,
    cancelled: 0,
    notes: 0,
    ideas: 0,
    pendingTotal: 0,
  };

  for (let i = 0; i < list.length; i++) {
    const it = list[i];
    if (it.type === "Todo") {
      if (it.status === "todo") stats.todo++;
      else if (it.status === "working") stats.working++;
      else if (it.status === "waiting") stats.waiting++;
      else if (it.status === "done") stats.done++;
      else if (it.status === "cancelled") stats.cancelled++;

      if (it.status !== "done" && it.status !== "cancelled") {
        stats.pendingTotal++;
      }
    } else if (it.type === "Note") {
      stats.notes++;
    } else if (it.type === "Idea") {
      stats.ideas++;
    }
  }

  return stats;
}

if (typeof module !== "undefined" && module && module.exports) {
  module.exports = {
    getSpaiPrefixes,
    generateId,
    parseRawItem,
    parseItems,
    formatItems,
    addItem,
    updateItem,
    removeItem,
    moveStatus,
    cycleStatus,
    filterItems,
    getStats,
  };
}
