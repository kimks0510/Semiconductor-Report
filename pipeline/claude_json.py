"""Call claude -p in a read-only, JSON-out mode and parse the result.

Claude never writes files here -- it only reads the given report files and
emits a JSON array as its final text response. Deterministic Python code
(the caller) does all the storage/dedup work. This keeps the LLM's job to
exactly what it's good at (reading prose, extracting structured facts) and
keeps everything else out of its allowed-tools surface.
"""
import json
import re
import subprocess
import time


def call_claude_for_json(prompt: str, max_attempts: int = 3) -> list:
    last_error = None
    for attempt in range(1, max_attempts + 1):
        print(f"Claude attempt {attempt} of {max_attempts}")
        result = subprocess.run(
            ["claude", "-p", prompt, "--permission-mode", "bypassPermissions", "--allowedTools", "Read"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        if result.returncode != 0:
            last_error = f"exit code {result.returncode}: {result.stderr[:2000]}"
            print(f"Claude attempt {attempt} failed: {last_error}")
        else:
            parsed = _extract_json_array(result.stdout)
            if parsed is not None:
                return parsed
            last_error = f"could not parse a JSON array from output: {result.stdout[:2000]}"
            print(f"Claude attempt {attempt} produced unparseable output")
        if attempt < max_attempts:
            time.sleep(60)
    raise RuntimeError(f"Claude JSON extraction failed after {max_attempts} attempts. Last error: {last_error}")


def _extract_json_array(text: str):
    text = text.strip()
    # Strip a markdown code fence if Claude added one despite instructions.
    fence = re.match(r"^```(?:json)?\s*(.*?)\s*```$", text, re.DOTALL)
    if fence:
        text = fence.group(1).strip()
    try:
        data = json.loads(text)
        if isinstance(data, list):
            return data
    except json.JSONDecodeError:
        pass
    # Last resort: find the first '[' ... matching ']' substring.
    start = text.find("[")
    end = text.rfind("]")
    if start != -1 and end != -1 and end > start:
        try:
            data = json.loads(text[start:end + 1])
            if isinstance(data, list):
                return data
        except json.JSONDecodeError:
            pass
    return None
