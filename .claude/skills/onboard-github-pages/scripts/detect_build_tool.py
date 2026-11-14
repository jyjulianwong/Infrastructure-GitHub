#!/usr/bin/env python3
"""Classify how a repo's GitHub Pages site is built, so the onboarding skill
can apply the right CNAME-placement + base-path recipe without re-deriving
the detection logic by hand each time (it was done by hand, the same way,
for 9 real repos before this script existed — see references/*.md for what
each variant name below means operationally).

Usage: detect_build_tool.py <repo_path>

Prints one JSON object to stdout. Never modifies anything.
"""

import json
import re
import sys
from pathlib import Path


def _read(path: Path) -> str | None:
    try:
        return path.read_text(errors="replace")
    except OSError:
        return None


def _find_workflows(repo: Path) -> list[Path]:
    wf_dir = repo / ".github" / "workflows"
    if not wf_dir.is_dir():
        return []
    return sorted(p for p in wf_dir.iterdir() if p.suffix in (".yml", ".yaml"))


def _deploy_workflow_info(repo: Path) -> dict:
    """Find the workflow (if any) that deploys to Pages, and classify it as
    'workflow' build type (actions/deploy-pages) or 'legacy' (a branch the
    workflow pushes prebuilt files to, e.g. peaceiris/JamesIves/gh-pages)."""
    for wf_path in _find_workflows(repo):
        text = _read(wf_path) or ""
        if "actions/deploy-pages" in text:
            return {"path": str(wf_path.relative_to(repo)), "build_type": "workflow"}
        m = re.search(r"peaceiris/actions-gh-pages", text)
        if m:
            branch = re.search(r"publish_branch:\s*(\S+)", text)
            folder = re.search(r"publish_dir:\s*(\S+)", text)
            return {
                "path": str(wf_path.relative_to(repo)),
                "build_type": "legacy",
                "branch": (branch.group(1) if branch else "gh-pages").strip("\"'"),
                "publish_dir": (folder.group(1) if folder else ".").lstrip("./").strip("\"'"),
            }
        m = re.search(r"JamesIves/github-pages-deploy-action", text)
        if m:
            branch = re.search(r"branch:\s*(\S+)", text)
            folder = re.search(r"folder:\s*(\S+)", text)
            return {
                "path": str(wf_path.relative_to(repo)),
                "build_type": "legacy",
                "branch": (branch.group(1) if branch else "gh-pages").strip("\"'"),
                "publish_dir": (folder.group(1) if folder else ".").strip("\"'"),
            }
        if re.search(r"gh-pages\b.*-d\s+(\S+)", text) or "npx gh-pages" in text or "gh-pages -d" in text:
            folder = re.search(r"gh-pages\s+-d\s+(\S+)", text)
            return {
                "path": str(wf_path.relative_to(repo)),
                "build_type": "legacy",
                "branch": "gh-pages",
                "publish_dir": (folder.group(1) if folder else "build").strip("\"'"),
            }
    return {}


def classify(repo: Path) -> dict:
    result: dict = {
        "repo_path": str(repo),
        "variant": "unknown",
        "evidence": [],
        "deploy_workflow": _deploy_workflow_info(repo),
    }

    # --- mkdocs ---
    mkdocs_yml = repo / "mkdocs.yml"
    if mkdocs_yml.is_file():
        text = _read(mkdocs_yml) or ""
        docs_dir_match = re.search(r"^docs_dir:\s*(\S+)", text, re.MULTILINE)
        site_url_match = re.search(r"^site_url:\s*(\S+)", text, re.MULTILINE)
        result["variant"] = "mkdocs"
        result["docs_dir"] = docs_dir_match.group(1) if docs_dir_match else "docs"
        result["has_site_url"] = bool(site_url_match)
        result["evidence"].append("mkdocs.yml present")
        return result

    # --- Vite ---
    for name in ("vite.config.js", "vite.config.ts", "vite.config.mjs"):
        vite_cfg = repo / name
        if vite_cfg.is_file():
            text = _read(vite_cfg) or ""
            base_match = re.search(r"base\s*:\s*(.+?)[,\n]", text)
            result["variant"] = "vite"
            result["vite_config_path"] = name
            result["base_line"] = base_match.group(0).strip() if base_match else None
            result["public_dir"] = "public" if (repo / "public").is_dir() else None
            result["evidence"].append(f"{name} present")
            return result
        # Vite apps sometimes live in a subdirectory (e.g. frontend/)
        for sub in repo.glob("*/" + name):
            text = _read(sub) or ""
            base_match = re.search(r"base\s*:\s*(.+?)[,\n]", text)
            result["variant"] = "vite"
            result["vite_config_path"] = str(sub.relative_to(repo))
            result["base_line"] = base_match.group(0).strip() if base_match else None
            subdir = sub.parent
            result["public_dir"] = (
                str((subdir / "public").relative_to(repo)) if (subdir / "public").is_dir() else None
            )
            result["evidence"].append(f"{sub.relative_to(repo)} present")
            return result

    # --- Create React App ---
    pkg_json = repo / "package.json"
    if pkg_json.is_file():
        text = _read(pkg_json) or ""
        try:
            pkg = json.loads(text)
        except json.JSONDecodeError:
            pkg = {}
        deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
        if "react-scripts" in deps:
            result["variant"] = "cra"
            result["homepage"] = pkg.get("homepage")
            result["public_dir"] = "public" if (repo / "public").is_dir() else None
            result["evidence"].append("package.json depends on react-scripts")
            return result

    # --- webpack with a CopyPlugin-driven src/ (no public/ dir) ---
    webpack_cfg_candidates = list(repo.glob("config/webpack*.js")) + list(repo.glob("webpack*.js"))
    if webpack_cfg_candidates and not (repo / "public").is_dir():
        for cfg in webpack_cfg_candidates:
            text = _read(cfg) or ""
            if "CopyPlugin" in text or "copy-webpack-plugin" in text:
                entry_dir = "src"
                basename_env = None
                env_match = re.search(r"(\w*BASENAME\w*)\s*:\s*null", text)
                if env_match:
                    basename_env = env_match.group(1)
                result["variant"] = "webpack-copy"
                result["webpack_config_path"] = str(cfg.relative_to(repo))
                result["entry_dir"] = entry_dir
                result["basename_env_var"] = basename_env
                result["evidence"].append(f"{cfg.relative_to(repo)} uses CopyPlugin, no public/ dir")
                return result

    # --- Raw static client/ dir (no build step) ---
    client_dir = repo / "client"
    if client_dir.is_dir() and (client_dir / "index.html").is_file():
        result["variant"] = "raw-static"
        result["publish_dir"] = "client"
        result["evidence"].append("client/index.html present with no build tooling detected")
        return result

    # Fallback: the deploy workflow's own publish_dir, if a raw static dir
    # outside client/ is being published directly (no framework signature
    # matched above).
    wf = result["deploy_workflow"]
    if wf.get("build_type") == "legacy" and wf.get("publish_dir"):
        candidate = repo / wf["publish_dir"]
        if candidate.is_dir() and (candidate / "index.html").is_file() and not any(
            (candidate.parent / f).exists() for f in ("package.json", "vite.config.js")
        ):
            result["variant"] = "raw-static"
            result["publish_dir"] = wf["publish_dir"]
            result["evidence"].append(
                f"workflow publishes {wf['publish_dir']}/ directly, no recognized build framework"
            )
            return result

    result["evidence"].append("no known pattern matched — see references/new-pages-site.md")
    return result


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: detect_build_tool.py <repo_path>", file=sys.stderr)
        sys.exit(2)
    repo = Path(sys.argv[1]).resolve()
    if not repo.is_dir():
        print(json.dumps({"error": f"not a directory: {repo}"}))
        sys.exit(1)
    print(json.dumps(classify(repo), indent=2))


if __name__ == "__main__":
    main()
