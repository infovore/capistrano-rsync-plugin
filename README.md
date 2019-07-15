# Capistrano 3.7.1+ rsync plugin

A plugin for Capistrano 3.7.1+ to enable deployment with RSync. Entirely adapted from [a gist by Stefan Daschek](https://gist.github.com/noniq/f73e7eb199a4c2ad519c6b5e2ba5b0df).

This emerged after [capistrano-rsync-bladrak](https://github.com/Bladrak/capistrano-rsync) appeared to [no longer support Capistrano 3.7.1](https://github.com/Bladrak/capistrano-rsync/issues/26)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'capistrano-rsync-plugin'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-rsync-plugin

Then, add this to your `Capfile` after loading `capistrano/deploy`

```ruby
require "capistrano/rsync"
install_plugin Capistrano::SCM::Rsync
```

## Usage

Deploying via rsync works in three steps:

1. A git checkout of the specified branched is performed into a local cache directory (`:rsync_local_cache`). Per default, this directory is persisted so that the next deploy only needs to do a “git pull” instead of a fresh clone. But you can delete this directory anytime, if you need/want do. (It will be recreated during the next deploy.)

2. The local cache directory is synced to the remote cache directory (`:rsync_remote_cache`) using rsync. Think of the remote cache directory as equivalent to the `repo` directory when deploying via git. It is there to avoid having to transfer all the files on each deploy. This, too, can be deleted (and will be recreated during the next deploy).

Per default, `:rsync_options` is set to exclude any git related files, thus none of these files will be transferred to the server.

3. The current state of the remote cache directory is copied to the release directory (also using rsync, but as the release directory is freshly created for each deploy, this is in fact just a full recursive copy)



## Configuration

Configuration option `:rsync_options` lets you specify options for the RSync command. The default is equivalent to:

```ruby
set :rsync_options, %w[--archive --delete --exclude=.git*]
```

The local cache directory relative to current is set by `:rsync_local_cache`. The default is equivalent to 

```ruby
set :rsync_local_cache, 'tmp/.capistrano-rsync-deploy'
```

The remote cache directory, relative to the deploy root, is set via `:rsync_remote_cache`, and is equivalent to:

```ruby
set :rsync_remote_cache, 'rsync-deploy'
```

The option `:rsync_deploy_build_path` makes it possible to deploy a subdirectory of the local cache. For instance, to only deploy the `public` directory, containing a compiled static site:

```ruby
set :rsync_deploy_build_path, 'public/'
```

Note the trailing slash. By default this is blank.

### New Capistrano Tasks

The `rsync` plugin introduces the following new tasks, which can be hooked onto using capistrano's before/after hooks:

* `set_current_revision` - calculate the current repository revision to check out
* `update_local_cache` - check out that revision to the local cache directory
* `update_remote_cache` - rsync local cache to the remote cache directory
* `create_release` - copy cache directory to the latest release directory

After `create_release`, the traditional Capistrano flow is resumed, and the latest release is symlinekd to current.

## Hooking build tasks on to capistrano-rsync

A primary use case for `capistrano-rsync` is the deployment of sites made with static site generators. Rather than storing compiled static sites in the repo along with sourcecode, it is recommended to build the site as part of the deployment process, and then deploy only the compiled site. This requires no dependencies on the server as a result.

As an example, let's deploy a repository made with the static site generator [Hugo](https://gohugo.io). We'll first add a task in our `deploy.rb` to build the site by installing necessary Javascript plugins, and then running Hugo:

```ruby
namespace :mysite do
  desc 'Locally build the hugo site'
  task :build_hugo do
    run_locally do
      within fetch(:rsync_local_cache) do
        execute :yarn
        execute :hugo, '--gc'
      end
    end
  end
end
```

This will change directory to the local cache, run `yarn`, and then run `hugo`. Now, we should add a hook to the `deploy.rb` to ensure this runs at the appropriate point in the build - after we've checked out the local cache:

```ruby
after 'rsync:update_local_cache', "mysite:build_hugo"
```

This will run `hugo`, and output the compiled site to `{LOCAL_CACHE_PATH}/public`.

Finally, we don't want to deploy all our source data - only the `public` directory, so we make sure we've set a configuration variable to do that in our `config/deploy.rb` file:

```ruby
set :rsync_deploy_build_path, "public/"
```

Of course, you can always override these variables and tasks in per-environment configuration files.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/infovore/capistrano-rsync.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
