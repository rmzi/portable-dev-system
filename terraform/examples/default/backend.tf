# Local backend — simplest path for a personal tool. State file stays in
# this directory; add it to your dotfiles repo .gitignore or commit it if you
# prefer deterministic reproduction across machines (accepting the tradeoff
# that state can contain references to secret material, though the IAM
# access keys themselves are already in sensitive outputs, not state).
terraform {
  backend "local" {}
}
