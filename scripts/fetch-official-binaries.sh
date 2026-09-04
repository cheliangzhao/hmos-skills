#!/usr/bin/env bash
#
# fetch-official-binaries.sh
#
# 从官方 HarmonyOS DFX Skills 仓库(GitCode, git-lfs 托管)按需拉取本仓库刻意
# 精简掉的运行时工具二进制,放入各技能期望的 scripts/ 路径下。
#
# 背景:本仓库不内置大体积二进制(analysis.exe 等),以保持仓库轻量;这些工具的
# 权威来源是官方仓库 developtools_dfx_skills(01-fault-analysis/…),其真实文件经
# Git LFS 分发。运行依赖这些二进制的技能前,若对应 scripts/ 下缺失工具,先执行本脚本。
#
# 拉取清单(官方路径 -> 本仓库路径):
#   jank-analysis:
#     01-fault-analysis/jank-analysis/scripts/analysis.exe|analysis_linux|analysis_mac
#         -> plugins/hmos-perf/skills/hmos-jank-analysis/scripts/
#     01-fault-analysis/jank-analysis/scripts/trace_streamer/trace_streamer_{linux,mac,windows.exe}
#         -> plugins/hmos-perf/skills/hmos-jank-analysis/scripts/trace_streamer/
#   nativeleak-analysis:
#     01-fault-analysis/nativeleak-analysis/scripts/trace_streamer_{linux,mac,windows.exe}
#         -> plugins/hmos-perf/skills/hmos-native-memleak-analysis/scripts/
#         (jsleak heap-cluster 流程亦复用 nativeleak 的 trace_streamer)
#   perf-analysis:
#     01-fault-analysis/perf-analysis/scripts/perf_mcp_server-<版本>.tar.gz
#         -> plugins/hmos-perf/skills/hmos-perf-analysis/scripts/
#
# 注:cppcrash 早期版本曾内置 llvm-objdump/llvm-addr2line/reliability_analyze 等
# 工具链,官方 GitCode 仓库不含它们(官方 cppcrash 为纯 Python),故本脚本无法拉取;
# 需要符号化/反汇编可选能力时,请通过官方 devecocli 完整分发获取。

set -euo pipefail

DFX_REPO="https://gitcode.com/openharmony-sig/developtools_dfx_skills.git"
# 官方仓库内与下面三个技能对应的分析目录;grep 用作允许清单校验
SPARSE_DIRS="01-fault-analysis/jank-analysis/scripts 01-fault-analysis/nativeleak-analysis/scripts 01-fault-analysis/perf-analysis/scripts"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JANK="$REPO_ROOT/plugins/hmos-perf/skills/hmos-jank-analysis/scripts"
NATIVE="$REPO_ROOT/plugins/hmos-perf/skills/hmos-native-memleak-analysis/scripts"
PERF="$REPO_ROOT/plugins/hmos-perf/skills/hmos-perf-analysis/scripts"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "缺少依赖命令: $1(需先安装)" >&2; exit 1; }; }
require_cmd git
require_cmd git-lfs

echo ">>> 拉取官方仓库元数据(浅克隆,稀疏检出)..."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --depth 1 --sparse "$DFX_REPO" "$TMP" >/dev/null 2>&1
cd "$TMP"
git sparse-checkout set $SPARSE_DIRS >/dev/null 2>&1
echo ">>> 下载官方 git-lfs 二进制对象..."
git lfs pull >/dev/null 2>&1 || { echo "git lfs pull 失败(检查 git-lfs 与网络)"; exit 1; }

copy_ok=0
# jank analysis 三平台
for f in analysis.exe analysis_linux analysis_mac; do
  [ -f "01-fault-analysis/jank-analysis/scripts/$f" ] || continue
  mkdir -p "$JANK"; cp "01-fault-analysis/jank-analysis/scripts/$f" "$JANK/$f"; chmod +x "$JANK/$f"
  echo "  + jank $f"; copy_ok=$((copy_ok+1))
done
# jank trace_streamer
for f in trace_streamer_linux trace_streamer_mac trace_streamer_windows.exe; do
  [ -f "01-fault-analysis/jank-analysis/scripts/trace_streamer/$f" ] || continue
  mkdir -p "$JANK/trace_streamer"; cp "01-fault-analysis/jank-analysis/scripts/trace_streamer/$f" "$JANK/trace_streamer/$f"; chmod +x "$JANK/trace_streamer/$f"
  echo "  + jank trace_streamer/$f"; copy_ok=$((copy_ok+1))
done
# nativeleak / native-memleak trace_streamer
for f in trace_streamer_linux trace_streamer_mac trace_streamer_windows.exe; do
  [ -f "01-fault-analysis/nativeleak-analysis/scripts/$f" ] || continue
  mkdir -p "$NATIVE"; cp "01-fault-analysis/nativeleak-analysis/scripts/$f" "$NATIVE/$f"; chmod +x "$NATIVE/$f"
  echo "  + native trace_streamer/$f"; copy_ok=$((copy_ok+1))
done
# perf-analysis tarball(版本号动态)
mkdir -p "$PERF"
cp 01-fault-analysis/perf-analysis/scripts/perf_mcp_server-*.tar.gz "$PERF/" 2>/dev/null && { echo "  + perf perf_mcp_server-*.tar.gz"; copy_ok=$((copy_ok+1)); }

echo ">>> 完成:共写入 $copy_ok 个官方二进制(如有平台不适用会跳过,如本机非对应系统)。"
echo "    若个别技能运行仍提示缺工具,多为官方仓库未收录(如 cppcrash llvm 工具链),请走 devecocli 官方分发。"
