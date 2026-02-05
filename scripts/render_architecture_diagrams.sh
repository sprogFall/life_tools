#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DIAGRAM_DIR="${ROOT_DIR}/docs/architecture/diagrams"
OUT_DIR="${ROOT_DIR}/docs/architecture/exports"
TOOL_DIR="${ROOT_DIR}/tools/plantuml"
JAR_PATH="${TOOL_DIR}/plantuml.jar"

if [[ ! -d "${DIAGRAM_DIR}" ]]; then
  echo "找不到 diagrams 目录：${DIAGRAM_DIR}" >&2
  exit 1
fi

if ! command -v java >/dev/null 2>&1; then
  echo "未找到 java，请先安装 JRE/JDK（用于运行 PlantUML）" >&2
  exit 1
fi

download_plantuml() {
  mkdir -p "${TOOL_DIR}"

  if [[ -f "${JAR_PATH}" ]]; then
    return 0
  fi

  echo "PlantUML jar 不存在，开始下载到：${JAR_PATH}"

  local metadata_url="https://repo1.maven.org/maven2/net/sourceforge/plantuml/plantuml/maven-metadata.xml"
  local version=""
  version="$(
    curl -fsSL "${metadata_url}" | python3 -c 'import re,sys; xml=sys.stdin.read(); m=re.search(r"<release>([^<]+)</release>", xml) or re.search(r"<latest>([^<]+)</latest>", xml); print(m.group(1) if m else "")'
  )" || true

  if [[ -z "${version}" ]]; then
    echo "无法从 Maven metadata 解析 PlantUML 版本号" >&2
    exit 1
  fi

  local jar_url="https://repo1.maven.org/maven2/net/sourceforge/plantuml/plantuml/${version}/plantuml-${version}.jar"
  local tmp="${JAR_PATH}.tmp"

  echo "下载：${jar_url}"
  curl -fsSL "${jar_url}" -o "${tmp}"
  mv "${tmp}" "${JAR_PATH}"
  echo "下载完成：${JAR_PATH}"
}

download_plantuml

if ! command -v dot >/dev/null 2>&1; then
  echo "提示：未检测到 graphviz 的 dot；序列图仍可渲染，但组件/类图在某些环境可能布局不稳定。"
  echo "建议安装：graphviz（Ubuntu/Debian: apt-get install graphviz）"
fi

render_one() {
  local file="$1"
  local rel="${file#${DIAGRAM_DIR}/}"
  local base="${rel%.puml}"

  local out_png="${OUT_DIR}/png/${base}.png"
  local out_svg="${OUT_DIR}/svg/${base}.svg"
  local out_pdf="${OUT_DIR}/pdf/${base}.pdf"

  mkdir -p "$(dirname "${out_png}")" "$(dirname "${out_svg}")" "$(dirname "${out_pdf}")"

  # PlantUML 支持 -pipe：从 stdin 读取并写到 stdout（便于自定义输出路径）
  # 注：部分 PlantUML 版本在 Java 17 下写 PNG 需要显式 export 内部 PNGMetadata。
  if ! java \
    --add-exports java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED \
    -Dfile.encoding=UTF-8 \
    -jar "${JAR_PATH}" -tpng -pipe -charset UTF-8 \
    <"${file}" >"${out_png}"; then
    echo "渲染失败（png）：${file} -> ${out_png}" >&2
    return 1
  fi

  if ! java \
    --add-exports java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED \
    -Dfile.encoding=UTF-8 \
    -jar "${JAR_PATH}" -tsvg -pipe -charset UTF-8 \
    <"${file}" >"${out_svg}"; then
    echo "渲染失败（svg）：${file} -> ${out_svg}" >&2
    return 1
  fi

  # PDF：优先用 svg 转换（PlantUML Maven jar 可能缺少 PDF 依赖）
  # 为避免“目标机器缺字库导致 PDF 中文变方框”，优先生成“图片型 PDF”（由 png 打包）。
  # 代价：PDF 文本不可选择/搜索，但展示最稳定。
  if python3 - <<PY >/dev/null 2>&1
from PIL import Image  # noqa: F401
PY
  then
    if ! python3 - "${out_png}" "${out_pdf}" <<'PY'; then
import sys
from PIL import Image

png, pdf = sys.argv[1], sys.argv[2]
img = Image.open(png)
if img.mode in ("RGBA", "LA"):
    bg = Image.new("RGB", img.size, (255, 255, 255))
    bg.paste(img, mask=img.split()[-1])
    img = bg
else:
    img = img.convert("RGB")
img.save(pdf, "PDF", resolution=300.0)
PY
      echo "渲染失败（pdf:png->pdf）：${out_png} -> ${out_pdf}" >&2
      return 1
    fi
  elif command -v rsvg-convert >/dev/null 2>&1; then
    if ! rsvg-convert -f pdf -o "${out_pdf}" "${out_svg}"; then
      echo "渲染失败（pdf:rsvg-convert）：${out_svg} -> ${out_pdf}" >&2
      return 1
    fi
  elif command -v inkscape >/dev/null 2>&1; then
    if ! inkscape "${out_svg}" --export-type=pdf --export-filename="${out_pdf}" >/dev/null 2>&1; then
      echo "渲染失败（pdf:inkscape）：${out_svg} -> ${out_pdf}" >&2
      return 1
    fi
  else
    if ! java \
      --add-exports java.desktop/com.sun.imageio.plugins.png=ALL-UNNAMED \
      -Dfile.encoding=UTF-8 \
      -jar "${JAR_PATH}" -tpdf -pipe -charset UTF-8 \
      <"${file}" >"${out_pdf}"; then
      echo "渲染失败（pdf:plantuml）：${file} -> ${out_pdf}" >&2
      echo "提示：建议安装 python3-pil（优先 png->pdf）或 librsvg2-bin（svg->pdf）。" >&2
      return 1
    fi
  fi
}

echo "开始渲染 PlantUML：${DIAGRAM_DIR}"

count=0
while IFS= read -r -d '' f; do
  render_one "${f}"
  count=$((count + 1))
done < <(find "${DIAGRAM_DIR}" -type f -name "*.puml" ! -name "_*.puml" -print0 | sort -z)

echo "渲染完成：${count} 个图"
echo "输出目录：${OUT_DIR}/(png|svg|pdf)/"
