---
type: llm
focus: trace
weight: 1
---

.github/workflows/ci.yml no longer sets ROUTER_BASENAME to /Demo-Webpack-App, while App.jsx's and webpack.common.js's own basename-handling code is left untouched
