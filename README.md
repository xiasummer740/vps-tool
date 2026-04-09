# 💎 VPS 开发者全能看板 (vps-tool)

这是一个专为开发者设计的 VPS 深度诊断工具。它可以一键扫描硬件资源、网络延迟、多语言开发环境版本，并利用智能逻辑溯源进程路径，提供实战级的部署建议。

### 🚀 一键运行 (无痕模式)

在任何 VPS 上直接复制并运行以下命令，即可看到深度看板。运行结束后脚本会自动销毁，不留痕迹。

\`\`\`bash
curl -sS -L https://raw.githubusercontent.com/xiasummer740/vps-tool/master/check.sh | bash
\`\`\`

### ✨ 核心功能

1.  **资源监控**：实时内存、Swap 状态及深圳回程三网延迟检测。
2.  **环境全量扫描**：涵盖 Nginx, Node.js, PM2, Python, Docker, MySQL 等常用环境版本。
3.  **进程深度溯源**：
    * **Nginx**：自动提取站点域名和配置文件。
    * **Node.js**：精准定位项目源码所在物理路径。
4.  **智能部署建议**：根据当前端口占用、内存余量、网络质量，动态生成避坑指南。

### 🛠️ 维护指南

如果需要更新脚本，请在本地修改 \`check.sh\` 后提交：

\`\`\`bash
git add check.sh README.md
git commit -m "update: 优化检测逻辑"
git push origin master
\`\`\`
