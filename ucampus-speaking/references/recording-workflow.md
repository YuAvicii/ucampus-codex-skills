# 逐题录音操作

## 选择题型和准备文字

| 页面要求 | 做法 |
| --- | --- |
| 翻译填空并逐句朗读 | 先核对各空的词和短语，录制完整英文句子。逐条验收填空、音轨和评分。 |
| 听后复述 | 在点击「原音」前准备已核对的文本。按页面要求听原音和提示音，等麦克风开始后播放目标说话人的台词。遇到含糊的切分，先对照可见脚本或合法取得的样音，也可用本地听写辅助。 |
| 段落朗读 | 使用当前页面的完整英文段落。多页题逐页查看评分，再从最后一页提交。 |
| 角色扮演 | 选 Scripts 和指定角色。每次该角色发言对应一个音频文件，顺序与网页对话一致。点击开始后由网页依次播放其他角色和录制本角色。总录音控件通常会结束整轮，单句结束时让网页自动转下一轮。 |
| 上传作品 | 按页面显示的格式限制准备音频。若允许 MP3，用下文脚本转换，等页面显示文件已上传再点击提交。 |

## Windows 浏览器录音和本地工具

网页录音需要正常使用当前站点的系统麦克风。先核对输入设备并做一次短录音，听回放确认收到了播放声。用户要求安静时可优先用页面的上传入口。现有虚拟麦克风测试无有效录音时，改用已获允许的录音方式。

分别在本技能目录运行以下示例。脚本创建命名为 `sentence-1.wav`、`sentence-2.wav` 的文件，序号对应条目中的台词先后。

```powershell
$clips = Join-Path $env:TEMP ('ucampus-oral-' + [guid]::NewGuid().ToString('N'))
pwsh -File ./scripts/New-UcampusSpeech.ps1 -EntryId u04-l2-green-fill -OutputDirectory $clips
pwsh -File ./scripts/Invoke-UcampusPlayback.ps1 -Directory $clips -Numbers 1
```

第一条生成脚本支持 `-TextFile` 读取自备纯文本，一行一条台词。默认输出 WAV，可选 `-Format mp3`（需要可用的 FFmpeg）。查看输出的时长再开始录制。技术词可在合成时用发音等价写法，例如缩写加字母间的空格，交给平台的填空仍用题面要求的形式。

播放脚本默认立即播放，录音图标已在采集时再调用。单次即将录制或角色扮演需要同步时，可以在网页开始前把本地脚本挂起：

```powershell
$run = Join-Path $clips 'playback-status.json'
& ./scripts/Invoke-UcampusPlayback.ps1 -Directory $clips -Numbers (1,2,3,4) -Mode OnChromeMicrophone -StatusFile $run
```

- 在支持后台等待的终端工具运行，再用浏览器 UI 开始录音。一次只运行一个播放队列，保持 Chrome 停在目标题目。同步模式只读 Windows 对 Chrome 麦克风的开始与停止状态，声音仍从系统默认输出设备播放。遇到不同 Chrome 安装位点时可提供当前已打开 Chrome 的 `-ChromeExe` 路径。
- 状态文件含 `phase` 和 `number`。普通题看到 `played` 就检查页面，若方形停止键仍在则立即点击。出现 `closed` 说明这轮麦克风已关闭，仍须以网页回放和评分判断保存结果。角色扮演的每条录音由页面关停，脚本等下一次开始。
- 若系统不提供可识别的麦克风活动记录、网页没有开始录音或等待超时，先检查当前题面的实际状态。可使用 `Immediate` 模式手动配合网页录音。若旧队列退出异常，先结束它再启动新队列。
- 只使用正常可见的上传和录音控件。录音期间保留题目在前，避免切去参考资料错过停止时点。浏览器连接或登录恢复后，从原题重新检查草稿与评分。

## 可选的本地听写

无法从页面获得原文、手头已有合法取得的样音文件时，可用 `scripts/transcribe-local.py` 输出带时间的候选文本。它需要本机已有的 Python、NumPy、faster-whisper、FFmpeg 及 CTranslate2 Whisper 模型目录。脚本只读取本地文件与已准备好的模型。

```powershell
python ./scripts/transcribe-local.py --model-dir 'D:/Models/faster-whisper-base.en' ./sample.mp3
```

听写文本没有说话人标注。复述题要回听切换位置或对照角色脚本。音频和台词均无法取得时，把该题标记为待核对。

## 验收

1. 当前题有音轨或回放，所有必录项都出现有效评分或已作答状态。
2. 如同一条录音出现明显丢句、静音或读错说话人，核对后才重录。
3. 提交整组练习后记录官方小结和实际分数。需要核对单元完成率时回到「学习记录」。

可用随包的 [Unit 4 四段示例音频](../assets/demo-green) 在录音前试听。它们按题目顺序编号，来自口语库的 `u04-l2-green-fill` 条目。
