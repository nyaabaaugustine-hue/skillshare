/**
 * SkillBridge web Python runner.
 *
 * Runs the same `python_app/skillbridge_exec.py` executor that the desktop
 * host-process runtime and the on-device runtime use, but inside Pyodide -
 * real CPython compiled to WebAssembly - so the browser build executes real
 * Python instead of canned output.
 *
 * It lives in a Worker for one reason: `runPython` blocks the thread it runs
 * on, and beginners write infinite loops. While this thread is busy the app
 * stays responsive, and Dart can stop a runaway program by terminating the
 * worker (which it does on timeout and on the Stop button).
 *
 * Protocol (every message is a JSON string, both directions):
 *   in  {type:'init',  indexURL}
 *   in  {type:'run',   id, job:{code, stdin, maxOutputChars}}
 *   out {type:'ready', pythonVersion}
 *   out {type:'init-error', message}
 *   out {type:'result', id, result:{...ExecutionResult JSON...}}
 *   out {type:'run-error', message}
 */

'use strict';

var pyodide = null;
var executorReady = false;

/**
 * Where to find the shared executor, in order of preference:
 *  1. the Flutter asset bundle (the single source of truth, python_app/), and
 *  2. a copy served straight from web/, next to this script. It does not depend
 *     on how the dev server or host exposes bundled assets, so the runner still
 *     starts when `assets/...` is not reachable. A unit test keeps the copy in
 *     sync with python_app/skillbridge_exec.py.
 */
var BASE_URL = new URL('.', self.location.href);
var HARNESS_URLS = [
  new URL('assets/python_app/skillbridge_exec.py', BASE_URL).href,
  new URL('skillbridge_exec.py', BASE_URL).href,
];

/** Fetches the executor source, trying each location in turn. */
async function fetchExecutorSource() {
  var attempts = [];
  for (var i = 0; i < HARNESS_URLS.length; i++) {
    var url = HARNESS_URLS[i];
    try {
      var response = await fetch(url, { cache: 'no-cache' });
      if (response.ok) {
        var text = await response.text();
        // A host that answers 200 with its index.html for unknown paths would
        // otherwise be mistaken for the executor.
        if (text.indexOf('def run_job_from_json') !== -1) return text;
        attempts.push(url + ' (not the executor)');
      } else {
        attempts.push(url + ' (HTTP ' + response.status + ')');
      }
    } catch (error) {
      attempts.push(url + ' (' + ((error && error.message) || error) + ')');
    }
  }
  throw new Error(
    'the executor asset is missing. Tried: ' + attempts.join(', ')
  );
}

/**
 * Builds `skillbridge_exec` as a real importable module and gives it a
 * browser-friendly `time.sleep`, which Pyodide otherwise refuses to define.
 *
 * The worker owns the sleeping program, so a bounded busy-wait is fine here:
 * it never touches the UI thread and Dart terminates the worker anyway.
 */
var BOOTSTRAP = [
  'import json, sys as _sb_sys, time as _sb_time, types',
  '',
  'PY_VERSION = _sb_sys.version.split()[0]',
  '',
  '_sb_module = types.ModuleType("skillbridge_exec")',
  '_sb_module.__file__ = "skillbridge_exec.py"',
  'exec(compile(__sb_exec_source, "skillbridge_exec.py", "exec"),',
  '      _sb_module.__dict__)',
  '_sb_sys.modules["skillbridge_exec"] = _sb_module',
  '',
  'def _sb_sleep(seconds):',
  '    try:',
  '        secs = float(seconds)',
  '    except (TypeError, ValueError):',
  '        return',
  '    if secs <= 0:',
  '        return',
  '    deadline = _sb_time.perf_counter() + min(secs, 60.0)',
  '    while _sb_time.perf_counter() < deadline:',
  '        pass',
  '',
  '_sb_time.sleep = _sb_sleep',
  '',
  'def _sb_run_job(job_json):',
  '    return json.dumps(',
  '        _sb_module.run_job_from_json(json.loads(job_json)))',
].join('\n');

function post(payload) {
  self.postMessage(JSON.stringify(payload));
}

self.onmessage = async function (event) {
  var message;
  try {
    message = JSON.parse(event.data);
  } catch (error) {
    return;
  }

  if (message.type === 'init') {
    await initialise(message);
  } else if (message.type === 'run') {
    await run(message);
  }
};

async function initialise(message) {
  try {
    var indexURL = message.indexURL;
    if (!self.loadPyodide) {
      await importScripts(indexURL + 'pyodide.js');
    }
    if (!pyodide) {
      pyodide = await self.loadPyodide({ indexURL: indexURL });
    }

    if (!executorReady) {
      var source = message.executorSource;
      if (typeof source !== 'string' ||
          source.indexOf('def run_job_from_json') === -1) {
        source = await fetchExecutorSource();
      }
      pyodide.globals.set('__sb_exec_source', source);
      pyodide.runPython(BOOTSTRAP);
      pyodide.globals.delete('__sb_exec_source');
      executorReady = true;
    }

    var version = pyodide.runPython('PY_VERSION');
    post({ type: 'ready', pythonVersion: String(version) });
  } catch (error) {
    post({
      type: 'init-error',
      message: String((error && error.message) || error),
    });
  }
}

async function run(message) {
  if (!pyodide || !executorReady) {
    post({ type: 'run-error', message: 'The Python runner is not ready yet.' });
    return;
  }

  try {
    pyodide.globals.set('__sb_job_json', JSON.stringify(message.job || {}));
    var payload = pyodide.runPython('_sb_run_job(__sb_job_json)');
    pyodide.globals.delete('__sb_job_json');

    post({
      type: 'result',
      id: message.id,
      result: JSON.parse(String(payload)),
    });
  } catch (error) {
    // The executor catches learner exceptions itself, so anything reaching
    // this branch is a runtime problem, not learner code.
    post({
      type: 'run-error',
      id: message.id,
      message: String((error && error.message) || error),
    });
  }
}
