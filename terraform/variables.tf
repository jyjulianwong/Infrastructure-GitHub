variable "github_owner" {
  description = "GitHub user/org that owns the repositories this stack manages"
  type        = string
  default     = "jyjulianwong"
}

variable "repositories" {
  description = "Repository names (under github_owner) to protect the default branch of"
  type        = list(string)
  default = [
    "Anon-OpenRouter-Chat",
    "Autotrader-Downloader-2026.3",
    "homebrew-lasagnastack",
    "Infrastructure-GitHub",
    "Investment-AI-Suite",
    "Investment-Fund-Reporting-AI",
    "Investment-News-Analysis-AI",
    "jyjulianwong",
    "LasagnaStack",
    "Market-Regime-Detector",
    "Obsidian-Server",
    "TradingAgents-Funds-Runner",
    "Turtle-Quant-1",
    "World-Take-Home-Income-Calculator",
  ]
}
