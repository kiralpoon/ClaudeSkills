"""Merge template sections into an existing file using HTML comment markers.

Usage: python3 merge_sections.py <target_file> <template_file>

Template files contain sections wrapped in:
  <!-- BEGIN TEMPLATE: section-name -->
  ...content...
  <!-- END TEMPLATE: section-name -->

Merge behavior:
  - Target has markers: replace each marked section with template version
  - Target has no markers: smart-merge via `claude -p` (preserves user content)
  - Template has no markers: skip (no-op)
"""
import re
import sys
import os
import subprocess

if len(sys.argv) < 3:
    print("  ✗ Usage: merge_sections.py <target> <template>", file=sys.stderr)
    sys.exit(1)

target_path, template_path = sys.argv[1], sys.argv[2]
filename = os.path.basename(target_path)

with open(target_path) as f:
    target_text = f.read()
with open(template_path) as f:
    template_text = f.read()

marker_re = re.compile(
    r'(<!-- BEGIN TEMPLATE: (\S+) -->.*?<!-- END TEMPLATE: \2 -->)',
    re.DOTALL,
)

template_sections = {m.group(2): m.group(1) for m in marker_re.finditer(template_text)}

if not template_sections:
    print(f"  ✗ No section markers in template for {filename} — skipping merge")
    sys.exit(0)

target_sections = {m.group(2): m.group(1) for m in marker_re.finditer(target_text)}

if target_sections:
    # Target has markers — replace each marked section with template version
    result = target_text
    updated = []
    for name, new_content in template_sections.items():
        if name in target_sections:
            result = result.replace(target_sections[name], new_content)
            updated.append(name)
        else:
            # New section in template — append before end of file
            result = result.rstrip() + "\n\n" + new_content + "\n"
            updated.append(name + " (new)")
    with open(target_path, 'w') as f:
        f.write(result)
    print(f"  ✓ Updated {filename} sections: {', '.join(updated)}")
else:
    # No markers in target — use claude -p to smart-merge.
    # This preserves all existing user content while integrating template
    # sections only where they are genuinely missing (no semantic duplicate).
    section_names = ', '.join(f'`{n}`' for n in template_sections)
    prompt = f"""You are merging two configuration files. Produce the merged result as a single file.

RULES:
1. Keep ALL content from the EXISTING FILE unchanged — do not reword, reorder, or remove any of it.
2. The TEMPLATE FILE contains sections wrapped in <!-- BEGIN TEMPLATE: name --> / <!-- END TEMPLATE: name --> markers.
3. For each template section: if the existing file already contains equivalent content (same topic, similar substance), SKIP adding that template section — the user's version takes precedence.
4. For each template section with NO equivalent in the existing file: append it at the end, preserving its markers exactly.
5. Output ONLY the raw merged file content. No commentary, no code fences, no explanation.

EXISTING FILE ({filename}):
{target_text}

TEMPLATE FILE:
{template_text}

Merged {filename}:"""

    try:
        proc = subprocess.run(
            ['claude', '-p'],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=120,
        )
        merged = proc.stdout.strip()
        if proc.returncode != 0 or not merged:
            raise RuntimeError(proc.stderr.strip() or "empty output")
        with open(target_path, 'w') as f:
            f.write(merged + "\n")
        print(f"  ✓ {filename} smart-merged via claude -p (sections: {section_names})")
    except Exception as e:
        # Fallback: append template sections so user content is never lost
        result = target_text
        for new_content in template_sections.values():
            result = result.rstrip() + "\n\n" + new_content + "\n"
        with open(target_path, 'w') as f:
            f.write(result)
        print(f"  ⚠ claude -p unavailable ({e}) — appended sections to {filename}")
