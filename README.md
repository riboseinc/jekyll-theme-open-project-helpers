# Open Project theme helpers

Jekyll plugin for the Open Project gem-based Jekyll theme by Ribose.

It provides the data reading and page generation capabilities
required by the theme.

Currently it enables such features as tag-based filtering
of open software and specification indexes, unified blog index,
fetching open project/software/specification data from their repos.

## Releasing

**Release this helpers gem and theme gem in tandem with matching versions.**
See [https://github.com/riboseinc/jekyll-theme-open-project-helpers](theme gem docs) for more.


1. Inside .gemspec within this repo’s root, update main gem version to the one being released.

2. Make a commit for the new release (“chore: Release vX.X.X”).

3. Execute `./develop/release`. This does the following:

   * Builds new gem version
   * Pushes gem to rubygems.org
   * Creates new version tag in this repository
   * Pushes changes to GitHub
