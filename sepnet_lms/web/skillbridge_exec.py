"""SkillBridge Python Lab - shared code executor.

This module contains the single source of truth for *how learner code is
executed* by SkillBridge Python Lab.  It is intentionally written against the
Python standard library only so that it can run in every environment we care
about:

  * The embedded CPython runtime shipped by Serious Python on Android/iOS
    (``python_app/main.py`` starts a tiny localhost HTTP server that calls
    :func:`execute`).
  * A host CPython interpreter during development and automated tests
    (``python_app/harness_cli.py`` is a thin CLI wrapper used by the Flutter
    ``ProcessPythonRuntime``).
  * Pyodide in the browser (``web/pyodide_worker.js`` loads this same file).

Keeping the executor in one file means the on-device behaviour and the
dev/test behaviour are the *same* code path, so what we test on the desktop is
what ships on the phone.

Security note
-------------
``exec`` of untrusted code inside the *same* interpreter as the host is **not**
a security sandbox.  This executor implements practical guard rails (input
injection so ``input()`` never blocks, output caps, a wall-clock limit, a
cancel hook and a curated builtin/module surface) but the real isolation
guarantees come from the outer layer:

  * On mobile the code runs inside the app's private CPython process.
  * In development it runs inside a short-lived child process that the Dart
    side kills on timeout.

See ``docs/SECURITY_AND_PRIVACY.md`` for the full discussion and the additional
protections required for production.
"""

from __future__ import annotations

import io
import json
import linecache
import sys
import time
import traceback
import uuid
from typing import Any, Dict, List, Optional

try:  # Pyodide ships a limited threading module; everything degrades gracefully.
    import threading
except Exception:  # noqa: BLE001 - pragma: no cover - environment dependent
    threading = None  # type: ignore[assignment]

# Sentinel markers let the Dart side reliably extract the JSON result from a
# stream that may also contain unrelated interpreter noise.
RESULT_START = "===SKILLBRIDGE_RESULT_START==="
RESULT_END = "===SKILLBRIDGE_RESULT_END==="

# Pseudo-filename used when compiling learner code. Registering the source in
# `linecache` under this name is what lets tracebacks show the offending line
# of the learner's own program instead of an anonymous `<skillbridge>` frame.
SOURCE_NAME = "<skillbridge>"

# Hard ceiling applied inside Python as a second line of defence. The Dart side
# applies its own, usually smaller, limit before this one is reached.
DEFAULT_MAX_OUTPUT_CHARS = 200_000

# Modules a beginner exercise is expected to reach for. Everything else is
# refused with a beginner-friendly ImportError instead of being imported; this
# is a guard rail, not a security boundary (see the module docstring).
_ALLOWED_MODULES = frozenset(
    {
        "abc",
        "array",
        "base64",
        "bisect",
        "calendar",
        "collections",
        "copy",
        "dataclasses",
        "datetime",
        "decimal",
        "enum",
        "fractions",
        "functools",
        "hashlib",
        "heapq",
        "itertools",
        "json",
        "math",
        "numbers",
        "operator",
        "queue",
        "random",
        "re",
        "statistics",
        "string",
        "sys",
        "textwrap",
        "time",
        "typing",
        "unicodedata",
    }
)

# Names that are useful for learners but that we deliberately keep out of the
# practice environment because they reach the filesystem, the network or the
# interpreter internals.
_BLOCKED_MODULES = frozenset(
    {
        "builtins",
        "ctypes",
        "gc",
        "importlib",
        "multiprocessing",
        "os",
        "pathlib",
        "shutil",
        "signal",
        "socket",
        "subprocess",
        "threading",
    }
)

# Builtins removed from learner code. `open`, `exec`, `eval`, `compile` and
# `__import__` are the escape hatches; the rest are process control.
_BLOCKED_BUILTINS = frozenset(
    {
        "__import__",
        "breakpoint",
        "compile",
        "eval",
        "exec",
        "exit",
        "globals",
        "help",
        "open",
        "quit",
    }
)


class _Cancelled(BaseException):
    """Raised inside learner code when the app asks to stop the current run.

    Derives from :class:`BaseException` on purpose: learner code that catches
    ``Exception`` (a common beginner habit) must not be able to swallow a Stop
    request.
    """


if threading is not None:

    class _Job:
        """Bookkeeping for one in-flight execution."""

        __slots__ = ("job_id", "thread_id", "cancel", "done", "deadline")

        def __init__(self, job_id: str, thread_id: int, deadline: Optional[float]):
            self.job_id = job_id
            self.thread_id = thread_id
            self.cancel = threading.Event()
            self.done = threading.Event()
            self.deadline = deadline

    _ACTIVE_JOBS: Dict[str, "_Job"] = {}
    _ACTIVE_LOCK = threading.Lock()
    # See execute(): learner code swaps the process-wide stdout/stderr, so only
    # one program may run at a time inside this interpreter.
    _EXEC_LOCK = threading.Lock()

    # Learner code replaces ``sys.stdout``/``sys.stderr`` for the duration of a
    # run, so two runs in flight at once would write into each other's buffers
    # (the executor runs inside the app's interpreter, where every thread shares
    # the process's stdout). Serialising executions keeps each result correct;
    # the app only ever shows one console, so nothing is lost.

    def _inject_async(thread_id: int, exc_type: type) -> bool:
        """Raise ``exc_type`` in another thread (CPython only, best effort)."""
        try:
            import ctypes
        except Exception:  # noqa: BLE001 - Pyodide/WASM has no ctypes
            return False
        try:
            count = ctypes.pythonapi.PyThreadState_SetAsyncExc(
                ctypes.c_ulong(thread_id), ctypes.py_object(exc_type)
            )
        except Exception:  # noqa: BLE001
            return False
        if count == 0:
            return False
        if count > 1:  # pragma: no cover - defensive: undo a bad injection
            ctypes.pythonapi.PyThreadState_SetAsyncExc(ctypes.c_ulong(thread_id), None)
            return False
        return True

    def _watch(job: "_Job", poll: float = 0.02) -> None:
        """Stop the job when it is cancelled or outlives its budget.

        This is the cross-platform half of the time limit: ``SIGALRM`` does not
        exist on Windows (and is unavailable in some embedded builds), so a
        watchdog thread is the only thing that can stop a runaway loop there.
        """
        while not job.done.wait(poll):
            if job.cancel.is_set():
                _inject_async(job.thread_id, _Cancelled)
                return
            if job.deadline is not None and time.perf_counter() >= job.deadline:
                _inject_async(job.thread_id, TimeoutError)
                return

    def cancel_job(job_id: str) -> bool:
        """Ask the executor to stop ``job_id``. Returns False if it is unknown."""
        with _ACTIVE_LOCK:
            job = _ACTIVE_JOBS.get(job_id)
        if job is None:
            return False
        job.cancel.set()
        return True

    def active_jobs() -> List[str]:
        with _ACTIVE_LOCK:
            return list(_ACTIVE_JOBS)

else:  # pragma: no cover - Pyodide without threads

    def cancel_job(job_id: str) -> bool:  # noqa: ARG001
        return False

    def active_jobs() -> List[str]:
        return []


def _build_input_function(lines: List[str]) -> Any:
    """Return a ``input()`` replacement backed by ``lines``.

    Using a list means ``input()`` can never block waiting for a terminal, which
    would freeze the app on a phone.
    """
    iterator = iter(lines)

    def _input(prompt: str = "") -> str:
        # Echo the prompt into stdout so learners see what was asked, matching
        # the behaviour they get in a normal terminal.
        if prompt:
            sys.stdout.write(str(prompt))
        try:
            value = next(iterator)
        except StopIteration:
            # Mirror real Python: running out of input raises EOFError.
            raise EOFError("Ran out of input. Add more input lines and run again.")
        # ``input`` strips the trailing newline.
        return str(value).rstrip("\n").rstrip("\r")

    return _input


def _register_source(code: str) -> None:
    """Publish ``code`` to :mod:`linecache` under :data:`SOURCE_NAME`.

    ``traceback`` looks up frame filenames in ``linecache``; without this a
    learner's traceback would show only an anonymous ``<skillbridge>`` frame
    with no source line, which is unhelpful when they are just starting out.
    """
    linecache.cache[SOURCE_NAME] = (
        len(code),
        None,
        code.splitlines(True),
        SOURCE_NAME,
    )


def _truncate(text: str, limit: int) -> Dict[str, Any]:
    """Truncate ``text`` to ``limit`` characters, keeping the newest output.

    Returns the (possibly truncated) text, a flag the UI uses to warn the
    learner, and the exact number of characters that were dropped so the reason
    is unambiguous.
    """
    if not text:
        return {"text": "", "truncated": False, "droppedChars": 0}
    if limit <= 0 or len(text) <= limit:
        return {"text": text, "truncated": False, "droppedChars": 0}

    dropped = len(text) - limit
    # The marker is part of the returned text, so it has to fit inside `limit`;
    # the tail is what a learner actually needs (the newest lines).
    marker = f"… {dropped} characters omitted …\n"
    room = limit - len(marker)
    if room <= 0:
        kept = text[-limit:]
    else:
        kept = marker + text[-room:]
    return {"text": kept, "truncated": True, "droppedChars": dropped}


def _execute_locked(
    code: str,
    *,
    stdin_lines: Optional[List[str]] = None,
    max_output_chars: int = DEFAULT_MAX_OUTPUT_CHARS,
    cpu_seconds: Optional[int] = None,
    job_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Execute ``code`` and return a structured result.

    The returned dictionary is JSON-serialisable and mirrors the fields the Dart
    ``ExecutionResult`` model expects::

        {
          "status": "success" | "error" | "timeout" | "cancelled",
          "stdout": str,
          "stderr": str,
          "exception": {"type": str, "message": str, "traceback": str,
                        "line": str} | None,
          "durationMs": int,
          "stdoutTruncated": bool,
          "stderrTruncated": bool,
          "droppedChars": int,
          "pythonVersion": str,
          "jobId": str,
        }
    """
    stdin_lines = list(stdin_lines or [])
    stdout_buf = io.StringIO()
    stderr_buf = io.StringIO()

    job_id = job_id or uuid.uuid4().hex
    started = time.perf_counter()

    # One wall-clock budget, enforced twice: SIGALRM where the platform has it
    # (it can interrupt a blocking `time.sleep`), plus a watchdog thread that
    # works everywhere and also handles Stop.
    alarm_installed = False
    job: Optional[Any] = None
    watchdog: Optional[Any] = None
    if threading is not None:
        deadline = started + cpu_seconds if cpu_seconds and cpu_seconds > 0 else None
        job = _Job(job_id, threading.get_ident(), deadline)
        with _ACTIVE_LOCK:
            _ACTIVE_JOBS[job_id] = job
        try:
            watchdog = threading.Thread(
                target=_watch, args=(job,), name=f"sb-watch-{job_id}", daemon=True
            )
            watchdog.start()
        except Exception:  # noqa: BLE001 - no threads: fall back to SIGALRM only
            watchdog = None
        if deadline is not None:
            alarm_installed = _install_alarm(int(cpu_seconds))

    globals_dict: Dict[str, Any] = {
        "__name__": "__main__",
        "__doc__": None,
        "__builtins__": _make_safe_builtins(stdin_lines),
    }

    status = "success"
    exception: Optional[Dict[str, str]] = None

    old_stdout, old_stderr = sys.stdout, sys.stderr
    try:
        sys.stdout = stdout_buf
        sys.stderr = stderr_buf
        try:
            # ``code`` is compiled first so we can distinguish syntax errors
            # (which get a beginner-friendly message) from runtime errors.
            _register_source(code)
            compiled = compile(code, SOURCE_NAME, "exec")
        except SyntaxError as exc:
            status = "error"
            exception = _format_syntax_error(exc)
        else:
            try:
                exec(compiled, globals_dict)
            except _Cancelled:
                status = "cancelled"
                exception = {
                    "type": "Cancelled",
                    "message": "Stopped by you.",
                    "traceback": "",
                }
            except TimeoutError as exc:
                status = "timeout"
                exception = {
                    "type": "TimeoutError",
                    "message": str(exc) or "Your program ran too long.",
                    "traceback": "",
                }
            except EOFError as exc:
                # ``input()`` ran out of supplied lines (see _build_input_function).
                status = "error"
                exception = {
                    "type": "EOFError",
                    "message": str(exc),
                    "traceback": "",
                }
            except SystemExit as exc:
                # ``sys.exit()`` / ``exit()`` should end the program cleanly.
                if exc.code not in (0, None):
                    status = "error"
                    exception = {
                        "type": "SystemExit",
                        "message": str(exc.code),
                        "traceback": "",
                    }
            except BaseException as exc:  # noqa: BLE001 - we must catch everything
                status = "error"
                exception = _format_exception(exc)
    finally:
        sys.stdout = old_stdout
        sys.stderr = old_stderr
        if alarm_installed:
            _cancel_alarm()
        if job is not None:
            job.done.set()
            with _ACTIVE_LOCK:
                _ACTIVE_JOBS.pop(job_id, None)
        if watchdog is not None:
            watchdog.join(timeout=0.5)

    duration_ms = int((time.perf_counter() - started) * 1000)

    out = _truncate(stdout_buf.getvalue(), max_output_chars)
    err = _truncate(stderr_buf.getvalue(), max_output_chars)

    return {
        "status": status,
        "stdout": out["text"],
        "stderr": err["text"],
        "stdoutTruncated": out["truncated"],
        "stderrTruncated": err["truncated"],
        "droppedChars": max(out["droppedChars"], err["droppedChars"]),
        "exception": exception,
        "durationMs": duration_ms,
        "pythonVersion": _python_version(),
        "jobId": job_id,
    }


def execute(
    code: str,
    *,
    stdin_lines: Optional[List[str]] = None,
    max_output_chars: int = DEFAULT_MAX_OUTPUT_CHARS,
    cpu_seconds: Optional[int] = None,
    job_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Execute ``code`` and return a structured result.

    Public entry point. Executions are serialised through ``_EXEC_LOCK`` because
    the runner swaps the interpreter's global ``sys.stdout``/``sys.stderr``;
    running two programs at once would otherwise blend their output.
    """
    if threading is None:  # pragma: no cover - Pyodide without threads
        return _execute_locked(
            code,
            stdin_lines=stdin_lines,
            max_output_chars=max_output_chars,
            cpu_seconds=cpu_seconds,
            job_id=job_id,
        )
    with _EXEC_LOCK:
        return _execute_locked(
            code,
            stdin_lines=stdin_lines,
            max_output_chars=max_output_chars,
            cpu_seconds=cpu_seconds,
            job_id=job_id,
        )


def _python_version() -> str:
    v = sys.version_info
    return f"{v.major}.{v.minor}.{v.micro}"


def _make_safe_builtins(stdin_lines: List[str]) -> Dict[str, Any]:
    """Return a curated ``builtins`` dict with ``input`` wired to ``stdin_lines``.

    The previous implementation copied *every* builtin and then removed
    nothing, so learner code could call ``open()`` and read the app bundle.
    A curated surface is both safer and easier to explain in the docs.
    """
    import builtins as _builtins

    namespace = {
        name: value
        for name, value in vars(_builtins).items()
        if not name.startswith("__") and name not in _BLOCKED_BUILTINS
    }
    # Keep the dunder names Python itself needs at runtime.
    namespace["__build_class__"] = _builtins.__build_class__
    namespace["__name__"] = "builtins"
    namespace["input"] = _build_input_function(stdin_lines)
    namespace["__import__"] = _guarded_import
    return namespace


def _guarded_import(
    name: str,
    globals: Optional[Dict[str, Any]] = None,
    locals: Optional[Dict[str, Any]] = None,
    fromlist: tuple = (),
    level: int = 0,
) -> Any:
    """``__import__`` that only exposes the beginner-friendly stdlib surface."""
    root = name.split(".")[0]
    if root in _ALLOWED_MODULES:
        return __import__(name, globals, locals, fromlist, level)
    if root in _BLOCKED_MODULES:
        raise ImportError(
            f"'{root}' is not available in the practice lab. "
            "The lab blocks modules that touch the device, the network or the "
            "filesystem — stick to the standard Python tools you have been learning."
        )
    raise ImportError(
        f"There is no module called '{root}' here. Check the spelling, or use a "
        "module from the standard library."
    )


def _format_syntax_error(exc: SyntaxError) -> Dict[str, str]:
    lineno = exc.lineno or 0
    offset = exc.offset or 0
    msg = exc.msg or "Invalid syntax"
    friendly = f"Syntax error on line {lineno}: {msg}"
    return {
        "type": "SyntaxError",
        "message": friendly,
        "traceback": "".join(traceback.format_exception_only(type(exc), exc)).strip(),
        "line": str(lineno),
        "offset": str(offset),
    }


def _format_exception(exc: BaseException) -> Dict[str, str]:
    """Format a runtime exception, hiding SkillBridge internal frames."""
    tb = exc.__traceback__
    tb_lines = traceback.format_exception(type(exc), exc, tb)
    # Drop frames that point at this executor so learners only see their own
    # code in the traceback.
    filtered = [line for line in tb_lines if "skillbridge_exec.py" not in line]
    if filtered and not filtered[0].startswith("Traceback"):
        filtered.insert(0, "Traceback (most recent call last):\n")
    return {
        "type": type(exc).__name__,
        "message": str(exc),
        "traceback": "".join(filtered).strip(),
        "line": str(_user_line(tb) or ""),
    }


def _user_line(tb: Any) -> Optional[int]:
    """1-based line of the *innermost learner frame* in ``tb``.

    Syntax errors have carried a line for a while; runtime errors did not, which
    left the console saying "something went wrong" with no location. Walking the
    traceback back to the frame whose filename is :data:`SOURCE_NAME` gives the
    line the learner actually needs to look at.
    """
    line: Optional[int] = None
    while tb is not None:
        if tb.tb_frame.f_code.co_filename == SOURCE_NAME:
            line = tb.tb_lineno
        tb = tb.tb_next
    return line


def _install_alarm(seconds: int) -> bool:
    """Best-effort SIGALRM based wall-clock limit (POSIX only).

    Preferred where available because it interrupts blocking C calls such as
    ``time.sleep``; the watchdog thread cannot.
    """
    try:
        import signal  # local import so non-POSIX just skips

        def _handler(signum, frame):  # noqa: ANN001
            raise TimeoutError(f"Execution exceeded {seconds} seconds")

        signal.signal(signal.SIGALRM, _handler)
        signal.alarm(int(seconds))
        return True
    except (ImportError, ValueError, AttributeError, OSError):
        return False
    except Exception:  # noqa: BLE001 - embedded interpreters vary
        return False


def _cancel_alarm() -> None:
    try:
        import signal

        signal.alarm(0)
    except Exception:  # noqa: BLE001
        pass


def run_job_from_json(job: Dict[str, Any]) -> Dict[str, Any]:
    """Convenience wrapper used by the CLI and the HTTP server."""
    return execute(
        job.get("code", ""),
        stdin_lines=job.get("stdin", []),
        max_output_chars=int(job.get("maxOutputChars", DEFAULT_MAX_OUTPUT_CHARS)),
        cpu_seconds=job.get("cpuSeconds"),
        job_id=job.get("jobId") or None,
    )
