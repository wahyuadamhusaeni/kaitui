// Joins the modules in src/ into one minified file for loadstring.
//   node build.js             -> dist/KaitUI.luau (minified)
//   node build.js --readable  -> also dist/KaitUI.readable.luau (unminified, for debugging; not pushed)
//   node build.js --check     -> fails if dist/KaitUI.luau is out of date
const fs = require("fs");
const path = require("path");

const root = __dirname;
const read = (file) => fs.readFileSync(path.join(root, file), "utf8").replace(/\r\n/g, "\n");

const HEADER = "-- KaitUI by KAKAIT. Built from src/ with build.js; don't edit.\n";

const modules = read("src/modules.txt")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));

const body = modules
    .map((file) => {
        const text = read(path.join("src", file));
        return text.endsWith("\n") ? text : text + "\n";
    })
    .join("");

// The library lives in one function so the 200-locals limit of Luau applies to it
// and not to the script that loads it. Every module shares that function's scope.
const library =
    "local Library = (function()\n" +
    body +
    "end)()\n" +
    "\n" +
    "return Library\n";

// Minifier: drops comments and whitespace, keeps every other token as written.

const OPERATORS = [
    "...", "..=", "//=",
    "..", "==", "~=", "<=", ">=", "//", "+=", "-=", "*=", "/=", "%=", "^=", "::", "->",
];

function longBracket(src, i) {
    // Returns the end index (exclusive) of a [==[ ... ]==] starting at i, or -1.
    const open = /^\[(=*)\[/.exec(src.slice(i, i + 64));
    if (!open) return -1;
    const close = "]" + open[1] + "]";
    const end = src.indexOf(close, i + open[0].length);
    if (end < 0) throw new Error(`unterminated long bracket at ${i}`);
    return end + close.length;
}

function quoted(src, i) {
    const q = src[i];
    let j = i + 1;
    while (j < src.length && src[j] !== q) {
        if (src[j] === "\\") j++;
        else if (src[j] === "\n") throw new Error(`unterminated string at ${i}`);
        j++;
    }
    if (j >= src.length) throw new Error(`unterminated string at ${i}`);
    return j + 1;
}

function interpolated(src, i) {
    let j = i + 1, depth = 0;
    while (j < src.length) {
        const c = src[j];
        if (c === "\\") j += 2;
        else if (depth === 0 && c === "`") return j + 1;
        else if (c === "{") { depth++; j++; }
        else if (c === "}") { depth--; j++; }
        else if (depth > 0 && (c === '"' || c === "'")) j = quoted(src, j);
        else j++;
    }
    throw new Error(`unterminated interpolated string at ${i}`);
}

// Length of the token at src[i], or 0 for whitespace/comments (handled by the caller).
function tokenEnd(src, i) {
    const c = src[i];
    if (/[A-Za-z_]/.test(c)) return i + /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i, i + 256))[0].length;
    if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(src[i + 1] || ""))) {
        const m = /^(0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9_]*\.?[0-9_]*([eE][+-]?[0-9_]+)?)/.exec(src.slice(i, i + 256));
        return i + m[0].length;
    }
    if (c === '"' || c === "'") return quoted(src, i);
    if (c === "`") return interpolated(src, i);
    if (c === "[") {
        const end = longBracket(src, i);
        if (end > 0) return end;
    }
    for (const op of OPERATORS) if (src.startsWith(op, i)) return i + op.length;
    return i + 1;
}

function tokenize(src) {
    const tokens = []; // { text, newlineBefore }
    let i = 0, newline = false;
    while (i < src.length) {
        const c = src[i];
        if (c === " " || c === "\t" || c === "\r" || c === "\n") {
            if (c === "\n") newline = true;
            i++;
        } else if (src.startsWith("--", i)) {
            const long = longBracket(src, i + 2);
            if (long > 0) {
                if (src.slice(i, long).includes("\n")) newline = true;
                i = long;
            } else {
                const end = src.indexOf("\n", i);
                i = end < 0 ? src.length : end;
            }
        } else {
            const end = tokenEnd(src, i);
            tokens.push({ text: src.slice(i, end), newlineBefore: newline });
            newline = false;
            i = end;
        }
    }
    return tokens;
}

function minify(src) {
    const tokens = tokenize(src);
    let out = "";
    let prev = null;
    for (const tok of tokens) {
        if (prev !== null) {
            if (tok.newlineBefore && tok.text === "(") {
                // `a\n(b)` would turn into a call on one line; keep the line break.
                out += "\n";
            } else {
                // A space only where the two tokens would otherwise read as one.
                // Luau reads a number on through any letters, digits and dots after it.
                const joined = prev + tok.text.slice(0, 4);
                const numberRunsOn = /^\.?[0-9]/.test(prev) && /^[A-Za-z0-9_.]/.test(tok.text);
                if (numberRunsOn || tokenEnd(joined, 0) !== prev.length || prev.endsWith("-") && tok.text.startsWith("-")) out += " ";
            }
        }
        out += tok.text;
        prev = tok.text;
    }
    return out + "\n";
}

const outputs = { "dist/KaitUI.luau": HEADER + minify(library) };
if (process.argv.includes("--readable")) outputs["dist/KaitUI.readable.luau"] = HEADER + library;

const check = process.argv.includes("--check");
let stale = false;
for (const [file, text] of Object.entries(outputs)) {
    const target = path.join(root, file);
    if (check) {
        if (!fs.existsSync(target) || fs.readFileSync(target, "utf8") !== text) {
            console.error(`out of date: ${file}`);
            stale = true;
        }
        continue;
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, text);
    console.log(`wrote ${file} (${(text.length / 1024).toFixed(0)} KB, ${modules.length} modules)`);
}
if (stale) process.exit(1);
