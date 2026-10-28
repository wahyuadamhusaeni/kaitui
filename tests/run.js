// Runs KaitUI for real, headless: the library and a script execute in the luau
// CLI against tests/mock.luau (a mock of the Roblox client API), and
// tests/scenario.luau drives the window like a player: every tab, minimize,
// every button, text boxes, configs, themes, Performance Mode, close.
// Fails on any error, and on any warning except in the misuse test, where
// warnings explaining the script's mistakes are the point (they are listed).
//
//   node tests/run.js            demo, quickstart, regressions and misuse, mouse and touch
//   node tests/run.js --verbose  also print the scripts' own output
//   node tests/run.js --script=path/to/script.luau [--scenario=path/to/scenario.luau] [--touch]
//                                run one script (and optionally another scenario) instead
//
// Needs the luau CLI (https://github.com/luau-lang/luau/releases): on PATH as
// `luau`, or pointed to with the LUAU environment variable.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const root = path.join(__dirname, "..");
const luau = process.env.LUAU || "luau";
const verbose = process.argv.includes("--verbose");
const read = (file) => fs.readFileSync(file, "utf8");

// Tests run against the readable build: same code as dist/KaitUI.luau, real line numbers.
execFileSync(process.execPath, [path.join(root, "build.js"), "--readable"], { stdio: ["ignore", "ignore", "inherit"] });
const dist = read(path.join(root, "dist", "KaitUI.readable.luau"));

// loadstring'd code binds type/typeof to the builtins, so the test copies call
// the mock's versions instead (the shipped file is untouched).
function mockTypes(src) {
    return src.replace(/(?<![\w.:])typeof\(/g, "__mocktypeof(").replace(/(?<![\w.:])type\(/g, "__mocktype(");
}
function longString(text) {
    let level = 0;
    while (text.includes("]" + "=".repeat(level) + "]")) level++;
    const eq = "=".repeat(level);
    return "[" + eq + "[" + text + "]" + eq + "]";
}

const scenarioArg = process.argv.find((a) => a.startsWith("--scenario="));
const scenarioFile = scenarioArg ? scenarioArg.slice(11) : path.join(__dirname, "scenario.luau");

function program(script, touch) {
    return `
local H = (function()
${read(path.join(__dirname, "mock.luau"))}
end)()
H.Quiet = ${verbose ? "false" : "true"}
H.setDist(${longString(mockTypes(dist))})
${touch ? 'local uis = rawget(H.services.UserInputService, "_extra") uis.TouchEnabled = true uis.KeyboardEnabled = false uis.MouseEnabled = false' : ""}
local realLoadstring = loadstring
loadstring = function(source, name)
    local fn, err = realLoadstring(source, name)
    if not fn then return nil, err end
    return function(...)
        local results = table.pack(fn(...))
        if type(results[1]) == "table" and results[1].Windows and results[1].CreateWindow then
            H.Library = results[1]
        end
        return table.unpack(results, 1, results.n)
    end
end
local scriptChunk = assert(realLoadstring(${longString(mockTypes(script))}, "=script"))
local scenarioChunk = assert(realLoadstring(${longString(mockTypes(read(scenarioFile)))}, "=scenario"))
H.phase = "script"
task.spawn(function()
    scriptChunk()
    H.scriptDone = true
end)
for _ = 1, 600 do
    if H.scriptDone then break end
    H.step(1 / 30)
end
if not H.scriptDone then H.fail("script", "did not finish within 20 s") end
local thread = coroutine.create(scenarioChunk)
local ok, err = coroutine.resume(thread)
if not ok then H.fail("scenario", debug.traceback(thread, err)) end
local guard = 0
while coroutine.status(thread) ~= "dead" and guard < 200000 do
    guard += 1
    H.step(1 / 30)
end
H.Quiet = false
print("RESULT phase=" .. tostring(H.phase) .. " errors=" .. #H.Errors .. " warnings=" .. #H.Warnings)
`;
}

const scriptArg = process.argv.find((a) => a.startsWith("--script="));
const scripts = scriptArg
    ? { [path.basename(scriptArg.slice(9))]: { file: scriptArg.slice(9), allowWarnings: process.argv.includes("--allow-warnings") } }
    : {
        demo: { file: path.join(root, "examples", "demo.luau") },
        quickstart: { file: path.join(__dirname, "quickstart.luau") },
        regressions: { file: path.join(__dirname, "regressions.luau") },
        misuse: { file: path.join(__dirname, "misuse.luau"), allowWarnings: true },
    };
const modes = scriptArg ? [process.argv.includes("--touch")] : [false, true];
let failed = false;
for (const [name, { file, allowWarnings }] of Object.entries(scripts)) {
    for (const touch of modes) {
        const label = `${name} (${touch ? "touch" : "mouse"})`;
        const target = path.join(os.tmpdir(), `kaitui-test-${name}-${touch ? "touch" : "mouse"}.luau`);
        fs.writeFileSync(target, program(read(file), touch));
        let output;
        try {
            output = execFileSync(luau, [target], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
        } catch (e) {
            output = (e.stdout || "") + (e.stderr || "");
            if (e.code === "ENOENT") {
                console.error("luau CLI not found: put it on PATH or set LUAU=<path to luau>");
                process.exit(2);
            }
        }
        const result = /RESULT phase=(\S+) errors=(\d+) warnings=(\d+)/.exec(output);
        const ok = result && result[1] === "done" && result[2] === "0" && (allowWarnings || result[3] === "0");
        console.log(`${ok ? "PASS" : "FAIL"}  ${label}${result ? `  (errors ${result[2]}, warnings ${result[3]})` : ""}`);
        if (allowWarnings && !touch && process.argv.includes("--warnings")) {
            const seen = new Set();
            for (const line of output.split("\n")) {
                if (line.startsWith("[warn]") && !seen.has(line)) {
                    seen.add(line);
                    console.log("   " + line);
                }
            }
        }
        if (verbose) {
            console.log(output);
        } else if (!ok) {
            // Every error with a few lines of its trace; warnings only where they fail the run.
            const lines = output.split("\n");
            const shown = [];
            lines.forEach((line, index) => {
                if (line.startsWith("[ERROR]") || (!allowWarnings && line.startsWith("[warn]"))) {
                    shown.push(...lines.slice(index, index + 6).filter((l) => !l.startsWith("[warn]") || l === line), "");
                }
            });
            console.log(shown.slice(0, 400).join("\n"));
        }
        failed = failed || !ok;
    }
}
process.exit(failed ? 1 : 0);
