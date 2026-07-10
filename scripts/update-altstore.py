#!/usr/bin/env python3
"""Regenerate altstore.json from the latest (or triggering) GitHub release.

Updates the version-specific fields of altstore.json to point at the release's
iWish.ipa: downloadURL, size, sha256 (computed by downloading the asset), the
version (read from the IPA's CFBundleShortVersionString so AltStore's update
check matches), marketingVersion (the tag), and date. Static metadata (name,
description, icon, …) is preserved.

Run by .github/workflows/update-altstore.yml on each release, or locally:
    GITHUB_REPOSITORY=johnbuckman/iwish RELEASE_TAG=v0.2-alpha \
        python3 scripts/update-altstore.py
Needs the `gh` CLI authenticated (GH_TOKEN / GITHUB_TOKEN in CI).
"""
import hashlib, json, os, plistlib, subprocess, sys, tempfile, zipfile
from datetime import datetime, timezone

REPO = os.environ.get("GITHUB_REPOSITORY", "johnbuckman/iwish")
IPA_NAME = "iWish.ipa"
JSON_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "altstore.json")
MIN_OS = "15.0"


def gh_api(path):
    return json.loads(subprocess.check_output(["gh", "api", path]))


def get_release():
    tag = os.environ.get("RELEASE_TAG")
    if tag:
        return gh_api(f"repos/{REPO}/releases/tags/{tag}")
    rels = [r for r in gh_api(f"repos/{REPO}/releases") if not r.get("draft")]
    if not rels:
        sys.exit("no releases found")
    return rels[0]  # newest first


def download(url):
    # curl (not urllib) so it works regardless of the local Python's cert store;
    # -L follows the release-asset redirect to storage.
    fd, path = tempfile.mkstemp(suffix=".ipa")
    os.close(fd)
    subprocess.check_call(["curl", "-fsSL", "-o", path, url])
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest(), os.path.getsize(path), path


def short_version(ipa_path):
    with zipfile.ZipFile(ipa_path) as z:
        for n in z.namelist():
            if n.startswith("Payload/") and n.endswith(".app/Info.plist") and n.count("/") == 2:
                return plistlib.loads(z.read(n)).get("CFBundleShortVersionString")
    return None


def main():
    rel = get_release()
    tag = rel["tag_name"]
    asset = next((a for a in rel.get("assets", []) if a.get("name") == IPA_NAME), None)
    if not asset:
        sys.exit(f"release {tag} has no {IPA_NAME} asset")
    url = asset["browser_download_url"]
    sha, size, ipa = download(url)
    short = short_version(ipa) or tag.lstrip("v")
    marketing = tag.lstrip("v")
    date = rel.get("published_at") or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    body = (rel.get("body") or "").strip()
    desc = (body[:2000] if body
            else f"{marketing}: see the GitHub release notes at https://github.com/{REPO}/releases/tag/{tag}")

    with open(JSON_PATH) as f:
        src = json.load(f)
    app = src["apps"][0]

    entry = {
        "version": short, "buildVersion": short, "marketingVersion": marketing,
        "date": date, "localizedDescription": desc,
        "downloadURL": url, "size": size, "sha256": sha, "minOSVersion": MIN_OS,
    }
    # newest first; dedup by version so re-runs replace rather than pile up
    app["versions"] = [entry] + [v for v in app.get("versions", []) if v.get("version") != short]
    # legacy top-level mirror for older AltStore/SideStore
    app.update(version=short, versionDate=date, versionDescription=desc,
               downloadURL=url, size=size, minOSVersion=MIN_OS)

    with open(JSON_PATH, "w") as f:
        json.dump(src, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.remove(ipa)
    print(f"altstore.json -> {marketing} (v{short}), size={size}, sha256={sha[:12]}…")


if __name__ == "__main__":
    main()
