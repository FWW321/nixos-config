---
name: autodl
description: AutoDL 租赁 GPU 实例的完整档案与操作手册 —— 覆盖平台机制（无卡/有卡模式、计费、数据盘生命周期）、网络现实（共享带宽上限、学术加速适用范围、镜像滞后坑）、当前 H3 实例的软件栈与模型布局、日常操作序列（开机检查、服务拉起、ComfyUI WebUI/API）、本机 nix 侧集成（ssh h3 / systemd ssh 隧道 h3-tunnel.service）。触发词：AutoDL、seetacloud、租的 GPU、远程实例、无卡开机、h3 实例、云端 ComfyUI、MiniMax H3 部署、实例扩容、数据盘。任何涉及该实例的连接、排障、升级、出片操作都先读本 skill。
---

# autodl

AutoDL 是国内 GPU 租赁平台；本机在 `users/fww/cloud.nix`（SSH matchBlock + systemd 直管 ssh 常驻隧道）声明式管理一台 RTX PRO 6000 96GB 实例，跑 MiniMax H3 视频生成。本 skill 是这台实例的**唯一档案**：平台机制、踩过的坑、当前软件栈全部在此，操作前先读对应小节。

## 平台心智模型

- **实例 = 系统盘(30G) + 数据盘**。系统盘重置即丢（可"保存镜像"固化）；数据盘挂 `/root/autodl-tmp`，持久，按 0.0053 元/日/GB 计费（**无论开关机**）。
- **两种开机模式**：无卡模式（约 0.1 元/时，GPU 不可见，适合下载/配置/编译）与有卡模式（按量计费，出片用）。关机不计 GPU 费。
- **实例重建后 SSH 端口会变** → 只改 `cloud.nix` 的 `port`，其余（matchBlock、隧道）自动派生。
- **面板服务**：JupyterLab(8888, base_url `/jupyter/`) 与 TensorBoard(6007) 由平台按 `/root/miniconda3/bin/<bin>` 路径拉起（配置在 `/init/jupyter/jupyter_config.py`，含固定 token）。实例上 miniconda 已删，该目录是**指向 h3-venv 的软链垫片**——重建垫片即可修复面板服务。

## 网络现实（实测，勿凭直觉）

| 事实 | 数值/结论 |
|---|---|
| 实例出口带宽 | ~14-15 MiB/s 聚合上限（共享带宽；连接数再多不叠加） |
| 学术加速 `source /etc/network_turbo` | **只**加速 github/huggingface；modelscope/aliyun/tuna 在 no_proxy 直连；对非学术源反而更慢 |
| 模型下载 | modelscope 优先（国内直连）；大文件 `aria2c -c -x16 -s16 -k8M --file-allocation=none` |
| pip 源 | tuna 对发布数小时~数天内的**新包没同步**（曾滞后 comfy-kitchen 22 个版本）；新包走 pypi.org，或本机下载 wheel 后 scp 上实例离线装 |
| pip 误报 | 带宽拥塞时 pytorch.org 索引页超时 → pip 报 "No matching distribution found"（**包其实存在**，别信，换时段或本机代下） |

## 当前 H3 实例档案（2026-08 部署）

硬件：RTX PRO 6000 Blackwell **96GB (sm_120)**，驱动 595.71.05（CUDA ≤13.2），25 核 Xeon 8470Q，120G 内存。数据盘 150G。

```
/root/autodl-tmp/
├── ComfyUI/models/      115G  ← fl2va/ref2va pruned bf16 (40.2G×2)
│                              ← qwen3vl int8_convrot (27.1G) + 双 VAE + turbo LoRA×2
├── ComfyUI-code/         62M  ← ComfyUI main + KJNodes + RTX VSR + Enhancement-Utils(资源监控)
│                              models→软链; user/default/workflows/H3/=10 个工作流,全部内置 RTX VSR 超分
│                              (不要时右键节点"绕过"(UI中文=Bypass,Ctrl+M,节点变紫#6a246a),勿用 scale=1 —— 仍跑增强网络)
├── h3-venv/             7.3G  ← 全部依赖 (Python 3.14.7)
├── uv-python/           111M  ← uv 独立 CPython 基座 (venv 重链于此)
├── h3_submit.py               ← 参数化 API 提交器: --prompt --turbo --steps --first-frame --seed --width --height --length
├── start_comfyui.sh           ← 一键启动 (sage attention 全局开; input/output 目录重定向在此)
├── restart.sh                 ← 重启 ComfyUI(队列非空时拒绝, FORCE=1 强制)
├── inputs/                    ← ComfyUI 输入目录(启动参数指定; 不是默认的 ComfyUI/input/)
├── outputs/                   ← 成片落点
└── logs/                      ← comfyui/jupyter/tensorboard/download 等日志
```

软件栈（全最新，2026-08-25 验证）：uv CPython 3.14.7 + torch **2.13.0+cu132** + torchvision 0.28.0+cu132 + torchaudio 2.11.0(停更终版，--no-deps 混搭) + sageattention 2.2.0 (AppMana abi3 wheel，已实测 sm_120 kernel) + comfy-kitchen 0.2.31 + transformers 5.15.1。

性能实测（1344×768 bf16，2026-08-25）：**7.17 s/step**@124f；turbo 8步=**80s**、4步草稿≈60s、I2V(4步)=60s、局部重绘(8步)≈100s、AddGuide(4步)≈50s、**R2V 362帧+turbo4+VSR2×=299s**。显存峰值：fl2va 69.5G、ref2va+362帧 **84.9G**（96G 卡满血扛住，这是本机型的独门能力）。

## 操作序列

**开机后（有卡模式）**：

```bash
ssh h3                                                # 或隧道已通直接用
nvidia-smi                                             # 确认卡
ssh h3 '/root/autodl-tmp/start_comfyui.sh &'           # ComfyUI :8188（setsid 后台）
ssh h3 'systemctl status jupyter 2>/dev/null; ss -tlnp | grep -E "8188|8888|6007"'
```

无卡模式下 `nvidia-smi` 报 Permission denied、`libcuda.so.1` file too short 是**正常现象**（驱动空壳占位），有卡开机自愈。

**出片**：浏览器 `http://localhost:8188`（经 autossh 隧道）→ 侧边栏 `工作流(w)` → `H3/` 文件夹，6 个预接好模型的工作流（T2V turbo/full、I2V 首帧、R2V+VSR 超分、局部重绘、任意帧引导）。CLI 批量/自动化：实例上 `./h3_submit.py --prompt "..." --turbo --steps 8`。产物 `/root/autodl-tmp/outputs/`，本机归档 `~/Videos/H3/`。全参数详解：本机 `~/Projects/h3/H3参数手册.md`。

**关机省钱**：AutoDL 控制台关机；隧道服务 30s 间隔静默重试，开机即恢复，本机无需任何操作。

## 坑清单（全部实测踩过，勿重复）

1. **`pkill -f <pattern>` 自杀**：pattern 出现在自己命令行文本里（如 SSH 传输中的脚本内容）→ 远程 shell 被杀，退出码 255 无输出。改用：写脚本文件再执行，或 `ps` 取 PID 精确 kill。
2. **ComfyUI 服务运维**：① 队列+历史**纯内存**（`PromptQueue.history` deque，cli_args 无持久化开关）——重启即清空 UI 历史/待跑队列（成片文件不丢）；② 资产库面板需 `--enable-assets` 旗标（已在 start_comfyui.sh），没它面板照常显示但 seeder 被禁、索引永远为空（sqlite `user/comfyui.db`，models/input/output 三目录自动扫描入库）；媒体面板"已生成"tab 读 `/api/jobs`=**纯内存队列数据合成（get_all_jobs(running,queued,history)），重启即清零**（官方已知限制：frontend issue #7168 / ComfyUI #13061，文档不载，云平台版才有持久 Job）——与资产 DB 的 job_id 无关（DB 里 job_id 持久但"已生成"不读它），重启后所有成片只在"已导入"tab；"已生成"= 本会话出片积累，属预期非故障；**"已导入"tab 实测只列 input 目录(=/internal/files/input,上传的图),DB 里的 outputs 成片索引在媒体面板无任何展示入口**——历史成片用 LoadImageOutput 节点(刷新下拉全列出)或磁盘 /root/autodl-tmp/outputs/ 找；③ restart.sh 有守卫：队列非空拒绝重启，FORCE=1 才强杀；④ 装新 custom_node 或改旗标后需重启才注册。
3. **H3 节点接线**：`MiniMaxH3ImageToVideo` 输出 `[0]=CONDITIONING, [1]=LATENT`；`prompt` 是**纯 STRING**（不走 CLIPTextEncode）；latent 也可由 `EmptyMiniMaxH3LatentAV` 提供。采样：`res_multistep` + scheduler `simple`。`MiniMaxH3AddGuide` **只输出 conditioning**（latent 用原节点的）。R2V 的 autogrow 参考在 API 里传 `ref_images: [["节点",0]]` 列表（不是 `ref_image_1` 展开名）。**A/B 终判（2026-08-25 四臂实测,详见 ~/Projects/h3/AB判决记录.md）**：直出=bf16+20步唯一（520s/10s片,19.9s/step）；测词=bf16+turbo4（150s,只验提示词执行度——D臂与full"完全不是一个级别"）；int8 判负已删（-19%时间有可见细节损失,"能跑bf16不用更差的"）；16步判负（有细节差）；8step LoRA 已删（544p 草稿场景被"低分辨率陷阱"共识废弃）。**已评估不部署**：lightx2v Prompt-Rewriter-LoRA（Qwen3.6-27B，H3-Context-IR 开源平替）——h3 skill 已更强覆盖其功能，且需 54GB 权重+独立 LLM 栈、磁盘余量不足；留档备查（若未来做无 agent 纯 WebUI 流程再启用）。**LoRA alpha 谜底**：LightX2V DMD 配置 alpha128 = rank128（实测两 LoRA 张量全 rank-128）→ 等效 ComfyUI strength 1.0；社区 0.75 强度是 544p LoRA 跑 768p 的错配补偿，分布内用法（4step_768p@768p）用 1.0。

**唯一工作流 `h3_多合一`**（YZ 骨架+实证配置，235 节点五管线单文件：文生视频 / 首尾帧生视频[fl2v 系] + 单图生视频 / 多参考生视频[r2v 系] + 二阶段采样[精修]）。**出厂全静音**（含 t2v，模型加载区常驻）——解禁目标组即用，组静音=该管线/输入不参与。**家族档位列**（加载区右缘）：`MiniMaxH3ModeSwitch`×2（fl2v/ref2v 各一）`mode` 三档下拉——full 直出（基线 20步/shift12/MP0.98）/ turbo 测词（`family` 锁蒸馏 LoRA 自动寻址+固定 4 步；`turbo_shift`/`turbo_mp` 可调，预填实证 fl2v 6.0/0.98、ref2v 12.0/0.5）/ draft 精修底（模型/步数保持 full 保结构，仅 MP→`draft_mp` 默认 0.4）；SigmaShift×2；SET 底栏（FL_steps/REF_steps/FL_megapixels/REF_megapixels）经 SET/GET 隧道到各管线 BS/选择器（选择器 megapixels 灰显=被隧道接管，改档去 MS）。**二阶段全自动**：mode 切 draft 前端 JS 自动解禁二阶段组、切走自动静音（加载时也按 mode 对齐=唯一真相源，组旁无开关）；粮道选择器 `MiniMaxH3RefineSource` auto 取活跃管线（优先级 文生>首尾>单图>多参考）+ 家族二采模型自动配套（fl系→FL2VA二采 / r2v系→REF2VA二采）；精修配方 beta/euler/4步/denoise 0.2（YZ 逆向实证）。**推荐画布**：首帧图像组 `MiniMaxH3RecommendCanvas` 只读输出 aspect/MP/宽高（竖图记得把目标管线 aspect 切 9:16，MP 通常不动）。**分辨率铁律**：MP 为 1024 基，0.98=原生 1344×768 顶格（⚠️1.0 算出 1376×768 超面积上限，禁用）、0.5=960×544（r2v turbo）、0.4=864×480（草稿）；multiple 必须 32（adapt_canvas 逐轴取整）。**时长**=PrimitiveFloat 秒数 → ComfyMathExpression 17k+5 公式 → length（与核心 temporal_shape 零行为差异）。**输出**=每管线 RTX VSR×2 ULTRA → CreateVideo(24fps 音画同轨) → SaveVideo（前缀 h3_t2v/h3_fl2v/h3_r2v_单图/h3_r2v_多参考/h3_精修；绕过 VSR 用 Ctrl+M，不要 scale=1）。**R2V 输入**：参考图像×6/视频×3/音频×3 组，解禁+选文件即参与（宁少勿多：参考总量≤12，视频≤3 各 2-15s 总≤15s，音频≤3 总≤15s 且须搭配图/视频；图推荐角色+场景）；`ref_video_audio_N`=`ref_video_N` 的原声音轨配对口（非独立参考）。**零预设防呆**（文件与 prompt 全空，空值在校验阶段拦下不烧 GPU）。**历史注记**：5 拆分版/t2v 中枢四模式/12 槽门控面板已删（tarball 留档）；AddGuide×R2V 组合 e2e 可行（知识在档：引导吸附向上取整 124→141 帧）。
4. **输入图适配陷阱**：生成分辨率永远 = 节点的 `width/height`，传入图被适配进画布。`first_frame` 是**纯拉伸**（方图接 1344×768 会横向变形 31%！）；`last_frame` 是保比例中心裁剪；R2V 参考图保比例缩放。方图要么改画布 768×768，要么先裁剪。采样器预览里的 512×293 是画布等比缩略，不是降分辨率。
5. **subgraph 模板**：ComfyUI 新前端模板（definitions.subgraphs）不能机械转 API 格式——用 `GET /object_info` 按输入签名手搓工作流最可靠。
6. **ComfyUI 目录重定向**：input/output/temp 由启动参数指定为 `/root/autodl-tmp/{inputs,outputs,temp}`——喂图到默认 `ComfyUI/input/` 会 FileNotFound。
7. **API 格式 JSON 与 WebUI**：拖到画布会自动转图格式；侧边栏直接打开是**空图**。图格式落盘只能走 UI（Ctrl+S）——userdata POST 接口 405（新 assets API 接管）。JSON 里的非节点键（如 `_说明`）会破坏 API 格式识别。动态组合框 v3 的子参数序列化为点路径（如 RTX VSR 的 `resize_type.scale`）。**autogrow 陷阱**：R2V 参考在 API 里传 `ref_images: [["节点",0]]` 列表（运行时唯一正确格式），但前端拖放 API→图格式转换会**静默丢弃该链接**（加载图像悬空、参考口全空、画布残留误导性残线）；图格式里 autogrow 输入名是点路径 `ref_images.ref_image_0`/`ref_videos.ref_video_0`/`ref_video_audios.ref_video_audio_0`/`ref_audios.ref_audio_0`。修复：浏览器 JS `loadImageNode.connect(0, r2vNode, 3)` 后 Ctrl+S。点 UI"队列"按钮会提交**当前画布**（API 轮询可能捕捉不到这次提交，易造成双提交重复出片——需要提交时要么只点按钮要么只走 API，别混用）。浏览器自动化注意：agent-browser 快照里按钮文本带私有区图标字符（如 `\ue95b 覆盖`），正则匹配按钮要用 `[^"]*覆盖` 而非空格通配；本机 PATH 里 `od` 曾被 open-design CLI 遮蔽（2026-09 改名 `open-design` 后已修复），十六进制查看兜底仍可用 python。
8. **conda 渠道**：tuna 的 anaconda defaults 镜像 404；别用 conda 建环境——`uv python install` 或 miniconda 自带 python `-m venv`。venv 换基座只需改 3 个符号链接 + pyvenv.cfg 的 `home`。
9. **torchaudio 停更**（终版 2.11.0 无 cu132）：`--no-deps` 装 cu130 版，再中和 `_extension/utils.py` 里的 CUDA 版本字符串比对（13.x 小版本二进制兼容）。
10. **ComfyUI 启动参数漂移**：`--cache-dir` 已不存在（改 `--cache-ram/--high-ram` 等）；`--use-sage-attention` 需独立 `sageattention` 包（comfy-kitchen 不提供该包名），wheel 源：AppMana `nodes.appmana.com/simple/cu130/`（abi3 通吃 3.14）。
11. **JupyterLab/TensorBoard 失联**：删过 miniconda 后面板按老路径找不到二进制 → 重建 `/root/miniconda3/bin` 软链垫片指向 h3-venv/bin，按面板原命令（`--config=/init/jupyter/jupyter_config.py`）拉起。
12. **8188 端口**：本机曾有的 ComfyUI 容器已删（ai/comfyui.nix 注销），8188 现在专属云隧道，勿再本地占用。

## 分工与关联

- 本机侧接入（matchBlock/隧道/公钥）声明：`users/fww/cloud.nix`（数据区 `clouds.h3`，换机只改此处）
- 本机工作流/手册副本：`~/Projects/h3/`（6 个 API JSON + `H3参数手册.md`，34 参数全覆盖）；成片归档 `~/Videos/H3/`
- 资源监控：实例已装 ComfyUI-Enhancement-Utils（WebUI 菜单栏 CPU/RAM/GPU/VRAM/温度/功耗 + 历史曲线；psutil/pynvml/piexif 已入 venv）
- **备份/复原架构（镜像+脚本=100% 复原）**：AutoDL 镜像只存系统盘(30G 内免费)，数据盘不进镜像。已预置 `/root/h3-snapshot/`(8.4G 进镜像)：h3-venv 全栈+ComfyUI-code(插件/工作流/自装节点)+uv-python+脚本+inputs，配 `RESTORE.sh`(拷回原路径，venv 绝对路径即恢复) + `download_models.sh`(110G 模型从 Comfy-Org/MiniMax-H3 核实下载，字节级+sha256 校验，hf-mirror 断点续传) + README 三步卡。保存镜像需控制台关机→更多→保存镜像；新实例选"我的镜像"→三步复原。成片 outputs 不在镜像（数据盘关机不丢，释放前拉回本机）
- **自装插件 `custom_nodes/h3_helpers/`**（仅两个不可替代节点）：`MiniMaxH3AutoCanvas`（图→三输出 width/height/补边图；mode=match跟图比例图原样直通[默认]/auto吸附最近常见比例/16:9/9:16/1:1/4:3/3:4，fill=blur/black/white/crop，复用核心 adapt_canvas+_resize——补边/裁剪保证零拉伸；竖图配 16:9 会两侧大片模糊边，auto 才是平衡点）与 `MiniMaxH3ModeSwitch`（turbo/full 一键四件套：LoRA×steps×shift×MP，配对值=ModelTC 蒸馏规格，LoRA 带实例级缓存）；i2v/inpaint/addguide 预接 AutoCanvas 全套（width/height/first_frame 补边图）。时长转换已改用官方件：PrimitiveFloat(秒)→ComfyMathExpression(17k+5 公式)→length，全部 8 工作流预接（原自装 SecondsToLength 已退役删除——与官方公式零行为差异，少养一个自定义节点）
- **Music3 不部署**（2026-08 决策）：ComfyUI 内置其节点但与 H3 零依赖——H3 原生联合生成音轨，成品配乐走 ffmpeg 混轨或 mmx-cli；半下载文件已清理，勿重复调研
- 出片 prompt 写作：提示词全模式用本仓库 h3 skill（官方 skills/h3-prompt-writing 骨架 + base-en/ref-en 指南原文 + 本地出片路径表）；官方仓另有 8 个品类模板 skill（product-ad/3d-animation 等），需要特定品类流水线时直读其 SKILL.md
- 2K/复杂多模态指令：官方 API（H3-Context-IR / H3-Regenerate-2K 未开源，本地只有 768p 能力；更高清用 RTX VSR 超分）
- 模型量化生态（GGUF/w4a8 等更小变体）：Comfy-Org/MiniMax-H3、Kijai/MiniMax-H3_comfy 仓库
