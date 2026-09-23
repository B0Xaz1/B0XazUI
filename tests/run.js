/**
 * tests/run.js
 * ====================================================================
 * Boots B0XazUI inside a mocked Roblox client (Lua 5.4 via wasmoon).
 * `game:HttpGet` is rewired to read the module tree straight off disk,
 * so the real loader path runs without touching the network.
 *
 * Two phases, each in a fresh VM:
 *   1. examples/Demo.lua  - does the documented API work end to end?
 *   2. tests/spec.lua     - behavioural assertions for every element.
 *
 *   cd tests && npm install
 *   cd .. && node tests/run.js
 * ====================================================================
 */

const fs = require('fs');
const path = require('path');
const { LuaFactory } = require('wasmoon');

const repoRoot = path.resolve(__dirname, '..');
const readRepoFile = (relativePath) =>
	fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');

let failed = false;

async function phase(name, file) {
	console.log(`\n──────── ${name} ────────`);

	const factory = new LuaFactory();
	const lua = await factory.createEngine();

	lua.global.set('__readFile', (relativePath) => {
		const full = path.resolve(repoRoot, relativePath);
		if (!full.startsWith(repoRoot)) {
			return null;
		}
		try {
			return fs.readFileSync(full, 'utf8');
		} catch (err) {
			return null;
		}
	});

	try {
		await lua.doString(readRepoFile('tests/mock/roblox.lua'));

		// Load init.lua exactly the way an executor would.
		await lua.doString(`
			local source = __readFile("init.lua")
			local chunk = assert(load(source, "=init.lua"))
			_G.B0XazUI = chunk()
		`);

		await lua.doString(readRepoFile(file));
		console.log(`${name}: OK`);
	} catch (err) {
		failed = true;
		console.error(`\n${name} FAILED\n${(err && err.message) || err}`);
		if (err && err.stack) {
			console.error(err.stack);
		}
	}

	await lua.global.close();
}

async function main() {
	await phase('demo  (examples/Demo.lua)', 'examples/Demo.lua');
	await phase('spec  (tests/spec.lua)', 'tests/spec.lua');

	if (failed) {
		process.exit(1);
	}
	console.log('\nAll phases passed.');
}

main();
