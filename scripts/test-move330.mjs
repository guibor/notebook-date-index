// Local exact-Move source gate; no tablet, network, or private state access.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {execFileSync as run, spawnSync} from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);
const profile = JSON.parse(fs.readFileSync('profiles/move-3.30.0.108-source.json'));
const target = JSON.parse(fs.readFileSync('target.json'));
assert.equal(target.device, profile.device);
assert.equal(target.firmware, profile.firmware);
const fw = process.env.FIRMWARE_ROOT || '../remarkable-beta-os-move-3300108/.cache/firmware/move/3.30.0.108';
const qmd = process.env.QMLDIFF || '/Users/mdf/code/remarkable-beta-os/.cache/tools/qmldiff-25681c3-bin';
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert.equal(hash(path.join(fw, 'usr/bin/xochitl')), profile.stockSha256, 'Wrong Move stock executable');
assert.equal(hash(qmd), '5d48704b2b55702bf553f65e0fac46bc2eacd72d3d995ac52b379df7e0ce973d', 'Unreviewed QMLDiff');
for (const [file, expected] of Object.entries(profile.resources))
    assert.equal(hash(path.join(fw, 'resources', file)), expected, `Changed stock ${file}`);
const env = {...process.env, NDI_TARGET: 'move', NDI_RESOURCES: path.resolve(fw, 'resources')};
run(process.execPath, ['build-qmd.mjs'], {env, stdio: 'inherit'});
const source = fs.readFileSync('build/notebook-date-index.source.qmd', 'utf8');
assert(!source.includes('ndiDatesButton'), 'Move must not gain the Pro sidebar');
assert(!source.includes('ToolbarTool.Type.'), 'Removed 3.29 toolbar type used');
assert(!source.includes('toolbar: root.toolbar'), 'Removed 3.29 toolbar owner used');
assert.equal((source.match(/group: ToolbarModel.ToolGroup.Utility/g) || []).length, 2);
assert(source.includes('visible: Toolbar.document.type === "note"\n'), 'Move notebook settings access must not depend on Pro layout');
assert.equal((source.match(/WITH \{ Values.ndiAddPage\(DocumentController, document,/g) || []).length, 4);

const walk = dir => fs.readdirSync(dir, {withFileTypes: true}).flatMap(entry =>
    entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
const manifests = {};
const table = process.env.MOVE_HASHTAB;
if (table) {
    assert(process.env.MOVE_HASHTAB_SHA256, 'Independently captured Move table hash required');
    assert.equal(hash(table), process.env.MOVE_HASHTAB_SHA256, 'Move runtime table mismatch');
}
for (const name of ['notebook-date-index', 'notebook-date-index-preview']) {
    let patch = `build/${name}.source.qmd`;
    if (table) {
        const hashed = `build/${name}.qmd`;
        fs.copyFileSync(patch, hashed);
        run(qmd, ['hash-diffs', table, hashed]);
        assert.equal(run(qmd, ['check-compatibility', table, hashed], {encoding: 'utf8'}).trim(), 'No compatibility errors found.');
        patch = hashed;
    }
    const tableArgs = table ? ['--hashtab', table] : [];
    const output = `build/${name}-composed`;
    run(qmd, ['apply-diffs', '--clean', ...tableArgs, '--version', profile.firmware, env.NDI_RESOURCES, output, patch], {stdio: 'pipe'});
    const files = walk(output);
    assert.equal(files.length, 7, 'Unexpected Move Dates resource count');
    for (const file of files) run('qmlformat', ['--ignore-settings', file], {stdio: ['ignore', 'ignore', 'pipe']});
    const rejected = output + '-wrong-version';
    run(qmd, ['apply-diffs', '--clean', ...tableArgs, '--version', '3.29.1.0', env.NDI_RESOURCES, rejected, patch], {stdio: 'pipe'});
    assert.equal(walk(rejected).length, 0, 'Wrong firmware was not rejected');
    manifests[name] = {sourceSha256: hash(`build/${name}.source.qmd`), candidateSha256: hash(patch), resourceCount: files.length};
}
for (const file of ['build/DatesPanel.qml', 'build/DatesPanel-preview.qml'])
    run('qmlformat', ['--ignore-settings', file], {stdio: ['ignore', 'ignore', 'pipe']});
const qtEnv = {...process.env, QT_QUICK_CONTROLS_STYLE: 'Basic', QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'};
for (const [generator, harness, marker] of [
    ['creation-runtime-test.mjs', 'creation-runtime', 'Creation runtime PASSED'],
    ['ui-harness.mjs', 'ui-harness', 'Dates UI runtime PASSED'],
    ['flash-harness.mjs', 'flash-harness', 'Dates flash runtime PASSED']]) {
    run(process.execPath, [generator], {stdio: 'inherit'});
    const result = spawnSync('qml', ['--disable-context-sharing', `build/${harness}.qml`],
        {env: qtEnv, encoding: 'utf8', timeout: 45000, maxBuffer: 4*1024*1024});
    const log = String(result.stdout || '') + String(result.stderr || '');
    fs.writeFileSync(`build/${harness}.log`, log);
    assert.equal(result.status, 0, `${harness}: ${result.error || log}`);
    assert(log.includes(marker), `Missing ${marker}`);
    assert(!/ReferenceError|TypeError|Cannot assign|is not a type|Error:/.test(log), log);
}
const report = {target: 'move-3.30.0.108', stockSha256: profile.stockSha256,
    runtimeTableSha256: table ? hash(table) : null,
    status: table ? 'offline-table-qualified-not-installed' : 'offline-source-qualified-runtime-table-pending',
    menuOnly: true, manifests,
    retainedPresentation: {panelSha256: hash('build/DatesPanel.qml'), dateTreeSha256: hash('build/DateTree.js')},
    deviceMutation: false, privateStateAccess: false};
fs.mkdirSync('build/move-3.30.0.108', {recursive: true});
fs.writeFileSync('build/move-3.30.0.108/qualification.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
