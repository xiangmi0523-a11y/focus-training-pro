#!/usr/bin/env python3
"""把思源宋体裁剪成只含 App 用到的字，体积从十几 MB 降到几百 KB。

用法: python3 scripts/subset_fonts.py <源字体目录> <输出目录>
"""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
src_dir = pathlib.Path(sys.argv[1])
out_dir = pathlib.Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)

chars = set()
for folder in ("App", "BrainCore/Sources"):
    for f in (root / folder).rglob("*.swift"):
        for ch in f.read_text(encoding="utf-8"):
            if ord(ch) >= 0x2E80:
                chars.add(ch)
# 常用标点与日期星期
chars.update("，。、？！：；“”‘’《》（）【】…—·￥¥月日年周星期一二三四五六七八九十零")
text = "".join(sorted(chars))
(out_dir / "chars.txt").write_text(text, encoding="utf-8")
print(f"汉字/符号 {len(chars)} 个")

for font in sorted(src_dir.glob("*.otf")):
    out = out_dir / font.name
    subprocess.run([
        sys.executable, "-m", "fontTools.subset", str(font),
        f"--text-file={out_dir / 'chars.txt'}",
        "--unicodes=U+0020-007E,U+00A0-00FF,U+2010-2027,U+3000-303F,U+FF01-FF5E",
        "--layout-features=*",
        "--name-IDs=*",
        "--name-languages=*",
        f"--output-file={out}",
    ], check=True)
    print(font.name, "->", out.stat().st_size // 1024, "KB")

(out_dir / "chars.txt").unlink()
