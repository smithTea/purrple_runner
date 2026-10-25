# Purrple IPA builder

This repository contains only the GitHub Actions builder. App and server source live at

Run **Actions → Build Purrple IPA → Run workflow**. Choose a source branch, tag, or commit (default: `master`). Download the unsigned IPA artifact and install with SideStore.

The runner fetches source using the repository secrets `SOURCE_SSH_KEY` (a dedicated read-only Forgejo deploy key) and `SOURCE_KNOWN_HOSTS` (pinned SSH host key). Source exists temporarily on the GitHub runner but is not committed here. IPA artifacts expire after 14 days.

The repository previously contained app source; those older commits remain in history.
