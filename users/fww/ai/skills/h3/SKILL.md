---
name: h3
description: Write MiniMax H3 video generation prompts for T2VA, I2VA, FL2VA, L2VA, and Ref2VA. Use when rewriting multimodal requests into H3 prompt structures, composing integrated_multimodal_description, overall_soundscape, and non_diegetic_music, aligning keyframes, or defining reference labels for images, videos, and audio.
---

# H3 Prompt Writing

官方 skill（MiniMax-AI/MiniMax-H3 `skills/h3-prompt-writing`）为唯一骨架；本副本附本地出片路径。指南原文在 `references/`（勿转述，用时直读）。

## Workflow

1. Identify the input mode: T2VA, I2VA, FL2VA, L2VA, or full-reference Ref2VA.
   - 判据 = 图与时间轴的关系：锚定具体时刻（首帧/尾帧）→ 关键帧系；全程身份/风格/运镜信息 → 参考系。单图且要"从这张图开始动" = I2VA；要"换场景仍保持这个人" = Ref2VA。
2. For base text/keyframe modes, read `references/base-en.txt` and follow its final prompt structure.
3. For full-reference mode, read `references/ref-en.txt` and follow its six-section rewrite format.
4. Preserve the exact field names, section order, labels, and timing notation from the selected guide.

## Base Modes

- T2VA: build the full audiovisual timeline from text.
- I2VA: start from the first frame and develop forward from it.
- FL2VA: describe the continuous path between the first and last frames.
- L2VA: infer a plausible opening and converge to the supplied last frame.

Use `integrated_multimodal_description`, `overall_soundscape`, and `non_diegetic_music` in the order shown in `references/base-en.txt`.

## Full-Reference Mode

Ref2VA rewrites use `subject_definitions`, `summary`, `retention_analysis`, `detailed_description`, `overall_soundscape`, and `non_diegetic_music` in that order. Reference labels stay consistent across all sections.

Read `references/ref-en.txt` for label rules, retention analysis, and complete examples.

## Output Rules

- Write rewrite sections in English; preserve dialogue, lyrics, and visible scene text in their original language.
- Describe each shot by composition, subjects, environment, actions, camera, sound, and the exact point where referenced content appears.
- Avoid plot summaries, unresolved reference labels, and timing that does not match the requested duration.

## Tips for Better Results

- Always match the total duration of the description to the requested video length (4–15 seconds).
- Keep reference labels consistent (e.g. `<Picture 1>`, `<Video 1>`, `<Audio 1>`) across every section.
- Prefer concrete visual and audio details over abstract words like "cinematic" or "beautiful".
- When using keyframes (I2VA / FL2VA / L2VA), clearly state how the first/last frame connects to the timeline.

## Effect Embeddings（效果包词汇表）

实例 `models/embeddings/` 预置社区效果包（Comfy-Org PR #50），提示词内直接引用，注入即生效（turbo/full 通用）：

`embedding:minimaxh3_kiss_camera`（凑近镜头亲吻）· `bullet_time`（子弹时间）· `fire_breath`（喷火）· `spiral_ascent`（螺旋升空运镜）· `storm_magic`（风暴魔法）· `dark_magic`（黑暗魔法）· `blooming_flowers`（繁花盛放）· `four_seasons`（四季变换）· `art_is_explosion`（艺术化爆炸）· `truman_show`（楚门世界式穿帮/戏中戏）

规则：全名=文件名去扩展名，拼错**静默忽略**（仅服务端日志 `does not exist`，成片无异常表现，新写法先瞄日志）；向量自带训练强度，不套权重语法；效果语义以一次 turbo 实测为准再定稿用词；新增包以实例 `ls models/embeddings/` 为准（本表 2026-08 快照）。

## 本地出片（实例侧）

唯一工作流 `h3_多合一`（五管线，出厂全静音，解禁目标组即用；档位在模型加载区 MS 节点 mode 下拉 full/turbo/draft）：

| 模式 | 解禁组 |
|---|---|
| T2VA | 文生视频 |
| I2VA / FL2VA / L2VA | 首尾帧生视频 + 首帧图像(+尾帧图像)；L2VA 只解禁尾帧 |
| Ref2VA 单图 | 单图生视频 + 首帧图像 |
| Ref2VA 多参考 | 多参考生视频 + 参考图像×≤6/视频×≤3/音频×≤3（`ref_video_audio_N` 为 `ref_video_N` 原声配对口） |
| 二阶段精修 | mode 切 draft 自动解禁（beta/euler/4步/0.2，粮道选择器 auto 取活跃管线） |

竖图：看推荐画布节点输出，把目标管线 aspect 切对应比例（如 9:16），MP 保持 0.98。提示词写进管线 PSM 大框，时长用管线 PrimitiveFloat 秒数。

CLI（独立构造 API，与工作流并行）：`~/Projects/h3/scripts/h3.py t2v|i2v|r2v "成稿" [--first 图|--last 图|--ref 图] [--turbo]`。

档位/分辨率/实例操作的权威表在 autodl skill，不在提示词职责内。官方仓库另有 8 个品类模板 skill（product-ad / 3d-animation / music-video 等，`skills/` 目录），需要特定品类流水线时去取。
