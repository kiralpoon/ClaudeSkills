"""Merge template sections into an existing file using HTML comment markers.

Usage: python3 merge_sections.py <target_file> <template_file>

Template files contain sections wrapped in:
  <!-- BEGIN TEMPLATE: section-name -->
  ...content...
  <!-- END TEMPLATE: section-name -->

Merge behavior:
  - Target has markers: replace each marked section with template version
  - Target has no markers: overwrite entire file with template
  - Template has no markers: skip (no-op)
"""
import re
import sys
import os

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
    # No markers in target — overwrite with template
    with open(template_path) as f:
        content = f.read()
    with open(target_path, 'w') as f:
        f.write(content)
    print(f"  ⚠ {filename} had no section markers — overwritten with template")
