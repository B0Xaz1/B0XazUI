/**
 * tests/preview.js
 * ====================================================================
 * Boots B0XazUI inside the mocked Roblox client, runs the Abyss
 * example (the recreation of the original design), serialises the
 * resulting instance tree and files it under preview/, where
 * preview/index.html renders the exact same layout in the browser.
 *
 *   cd preview && node ../tests/preview.js && serve preview/
 * ====================================================================
 */

const fs = require('fs');
const path = require('path');
const { LuaFactory } = require('wasmoon');

const repoRoot = path.resolve(__dirname, '..');
const readRepoFile = (relativePath) =>
	fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');

async function main() {
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

	await lua.doString(readRepoFile('tests/mock/roblox.lua'));

	await lua.doString(`
		local source = __readFile("init.lua")
		local chunk = assert(load(source, "=init.lua"))
		_G.B0XazUI = chunk()
	`);

	await lua.doString(readRepoFile('examples/Abyss.lua'));
	await lua.doString('_G.__PREVIEW__ = _G.B0XazUI_UI');

	const result = await lua.doString(readRepoFile('tests/preview.lua'));
	const json = Array.isArray(result) ? result[0] : result;

	if (typeof json !== 'string' || json.length === 0) {
		throw new Error('preview.lua returned no JSON');
	}

	const outDir = path.join(repoRoot, 'preview');
	fs.mkdirSync(outDir, { recursive: true });
	fs.writeFileSync(path.join(outDir, 'data.json'), json);
	// As an inline script the preview also opens over file:// (no fetch).
	fs.writeFileSync(path.join(outDir, 'data.js'), `window.__PREVIEW_DATA__ = ${json};\n`);
	console.log(`preview/data.json + data.js written (${json.length} bytes)`);

	await lua.global.close();
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
