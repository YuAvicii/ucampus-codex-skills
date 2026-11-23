# U校园 Codex 技能包

仅适用于《新探索研究生英语（基础级）视听说教程》Unit 1–6（ISBN 978-7-5213-2799-1）。

<img src="assets/textbook-cover.png" alt="《新探索研究生英语（基础级）视听说教程》教材封面" width="260">

- [课程作答与进度核对](ucampus-coursework/SKILL.md) 包含答案页索引、作答流程和提交验收。
- [口语录音](ucampus-speaking/SKILL.md) 包含口语台词、示例 WAV 和 Windows 音频生成及播放脚本。

## 安装

从 [GitHub Releases](https://github.com/YuAvicii/ucampus-codex-skills/releases) 下载 `ucampus-codex-skills.zip` 并解压。将 `ucampus-coursework` 和 `ucampus-speaking` 并排复制到用户技能目录 `~/.agents/skills/`。Windows 可在资源管理器打开 `%USERPROFILE%\.agents\skills`。也可以直接复制本仓库的两个技能目录。

在 Codex 的「技能」列表中确认两项技能已加载，并在对话中调用 `$ucampus-coursework` 或 `$ucampus-speaking`。

## 在线作答与录音

运行在线任务时，技能会通过可控制的浏览器打开 U校园。需要登录时，由用户在网页中完成登录。确认可以访问「我的课程」后，再进入本教材的课程。

Windows 语音生成需要 PowerShell 7 和英文系统语音。网页录音需要在浏览器中授予 U校园麦克风权限。按[录音流程](ucampus-speaking/references/recording-workflow.md)先测试一条并听回放。

教材与参考答案来源见[答案索引](ucampus-coursework/references/answer-index.md)。

## 致谢

感谢大家的关注和支持！如果这套技能对你有帮助，欢迎给仓库点个 ⭐ Star。
