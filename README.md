# bundler-gsoc

Documentation and Utility Scripts for Bundler GSoC Mentoring

The following is documentation and useful for mentoring a Bundler/Ruby organization Google Summer of Code student for any proposal that is along the lines of "Maintain Bundler".

It currently includes:

- Dockerfile of a debian jessie environment with a whole bunch of linux package dependencies, ruby `2.3.1`, and rubygems `2.6.4` installed.

### Github to Tracker Script

This script imports all open issues and pull requests for the `bundler/bundler` repo into a Tracker board as stories with the associated labels.

To invoke:

```bash
PIVOTAL_TRACKER_API_KEY=<tracker-api-key> BUNDLER_PROJECT_ID=<tracker-project-id> BUNDLER_REQUESTER_ID=<requester-id> GITHUB_API_TOKEN=<github-token> ./github-to-tracker-import.rb
```

To delete all existing stories on the tracker project before populating it, invoke the above command with the additional environmental variable specified:

```bash
REFILL_TRACKER_BOARD=true
```
