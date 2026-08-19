# filepath: ~/nixos-config/pkgs/pdf-inspector/default.nix
# pdf-inspector (Firecrawl): 快速 PDF 分类与文本提取,纯 Rust,无 OCR
# 源码: https://github.com/firecrawl/pdf-inspector  crates.io: pdf-inspector 0.1.7
#
# 产出三个 bin: pdf2md(PDF→Markdown 主力)、detect-pdf(类型检测/OCR 分流)、dump_ops(调试)
# default feature 不含 pyo3 → 纯 Rust 编译,无 Python 依赖、无 onnxruntime/ML 模型
# opencode skill (users/fww/ai/skills/pdf-inspector) 经 skills.nix 的 package 字段绑定此包
#
# 无 MSRV 约束 (rust_version: null, edition 2021),用 nixpkgs 默认 stable rustPlatform
{ lib, rustPlatform, fetchCrate }:

rustPlatform.buildRustPackage rec {
  pname = "pdf-inspector";
  version = "0.1.7";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-S6/NohXpIHIcpCUOGiO9hHwK5cxDYS83cf646i5AREQ="; # crates.io 0.1.7
  };

  cargoHash = "sha256-/PTqpmL2JdnK/Ejo3IAK/DqTSVrA9zTmFnmRPoc4tLc="; # cargo 依赖 vendor FOD

  # 上游 0.1.7 的 default feature 是 [](features: {"default":[],"python":["pyo3"]})
  # 显式置空,防止上游未来把 default 改成含 pyo3 而拉入 Python 扩展
  buildFeatures = [ ];

  # 跳过上游测试: sandbox 缺网络/fixture,上游 CI 已覆盖;此包只做 packaging,不 own 上游代码
  doCheck = false;

  meta = {
    description = "Fast PDF inspection, classification, and text extraction with smart scanned vs text-based detection";
    homepage = "https://github.com/firecrawl/pdf-inspector";
    license = lib.licenses.mit;
    mainProgram = "pdf2md";
  };
}
