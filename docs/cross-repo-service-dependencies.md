# Cross-Repo Service Dependency Pattern

## Context

Some repos in this workspace depend on services provided by other repos at runtime.
For example, `video_agent` calls chatterbox's TTS HTTP API when running Stage 5 audio
generation. These are **runtime service dependencies** — not code or venv dependencies.

The goal is to keep repos fully isolated while still enabling integration tests that
require a live service from another repo.

---

## Principle

**Repos never share Python code or venvs.** The only sanctioned cross-repo coupling is
an HTTP API:

- The provider repo exposes an HTTP server (FastAPI / uvicorn).
- The consumer repo's test fixture starts that server as a subprocess, using the
  provider's own venv.
- No provider code is imported into the consumer's Python process.
- The fixture is responsible for full server lifecycle: start → health-check → teardown.

---

## Known Service Relationships

| Consumer | Provider | Protocol | Port |
|----------|----------|----------|------|
| video_agent (stage 5 TTS) | chatterbox | HTTP `POST /tts` | 8000 |

---

## Pytest Fixture Pattern (consumer side)

Place a session-scoped fixture in the consumer repo's `tests/integration/conftest.py`.
The fixture:

1. Skips (not fails) if the provider venv is absent — so CI without the service just
   skips gracefully.
2. Starts the server subprocess using the provider's own venv Python.
3. Polls the provider's `/health` endpoint (1 s interval, 60 s timeout).
4. Yields the base URL to the test.
5. Terminates the process on teardown.

```python
# repos/video_agent/tests/integration/conftest.py
import os, subprocess, time
import pytest, requests

CHATTERBOX_PYTHON = "/workspaces/.venvs/chatterbox/bin/python"
CHATTERBOX_DIR    = "/workspaces/hub/repos/chatterbox"
CHATTERBOX_PORT   = 8000

@pytest.fixture(scope="session")
def chatterbox_server():
    if not os.path.exists(CHATTERBOX_PYTHON):
        pytest.skip("chatterbox venv not found at " + CHATTERBOX_PYTHON)
    proc = subprocess.Popen(
        [CHATTERBOX_PYTHON, "-m", "uvicorn", "app.main:app",
         "--host", "127.0.0.1", "--port", str(CHATTERBOX_PORT)],
        cwd=CHATTERBOX_DIR,
    )
    url = f"http://127.0.0.1:{CHATTERBOX_PORT}"
    deadline = time.time() + 60
    while time.time() < deadline:
        try:
            if requests.get(f"{url}/health", timeout=2).status_code == 200:
                break
        except Exception:
            pass
        time.sleep(1)
    else:
        proc.terminate()
        pytest.fail("[ERROR] chatterbox server did not start within 60s")
    yield url
    proc.terminate()
    proc.wait(timeout=10)
```

---

## Provider Requirements

Any repo that acts as a service provider must:

1. Be startable via its own venv:
   ```bash
   /workspaces/.venvs/<repo>/bin/python -m uvicorn app.main:app \
     --host 127.0.0.1 --port <port>
   ```
2. Expose a `GET /health` endpoint that returns HTTP 200 once the model/server is ready.
3. Not change its port or startup command without updating this document and the
   consumer's fixture.

---

## Test Marker Convention

Consumer repos should register a pytest marker for each service dependency:

```ini
# pytest.ini
markers =
    requires_chatterbox: requires the chatterbox TTS server to be running
```

Mark tests that need the service:

```python
@pytest.mark.integration
@pytest.mark.requires_chatterbox
def test_audio_generation_via_chatterbox(chatterbox_server):
    ...
```

Run only these tests:

```bash
pytest tests/integration/ -v -s -m "integration and requires_chatterbox"
```

---

## Implementation Checklist

When adding a new cross-repo service dependency:

- [ ] Add the relationship to the table above.
- [ ] Add a session-scoped fixture in the consumer's `tests/integration/conftest.py`.
- [ ] Register the `requires_<provider>` pytest marker in the consumer's `pytest.ini`.
- [ ] Add a note to the provider's `CLAUDE.md` describing its role as a service dependency.
- [ ] Verify that tests skip cleanly when the provider venv is absent.
