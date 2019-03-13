# Install Zync (only explained for MacOS so far)
1. Download this repository.
`git clone git@github.com:3scale/zync.git`

2. Move to the folder of the project.
`cd zync`

3. Install the dependencies. There is `Brewfile` containing all the dependencies.
`brew bundle`

4. Start postgres.
`brew services start postgresql`

5. Setup Zync.
`./bin/setup`

The command `brew services start postgresql` starts the service of PostgreSQL. If `./bin/setup` aborts, make sure that the `PostgreSQL` service is running. Verify with `brew services list` that has a status `started` and looking green. If the status is `started` but coloured orange, fix the errors indicated in the log located in `/usr/local/var/log/postgres.log`
