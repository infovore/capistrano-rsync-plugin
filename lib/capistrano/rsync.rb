# load File.expand_path('../tasks/rsync.rake', __FILE__)
require 'capistrano/scm/plugin'

class Capistrano::SCM
  # Usage: Add this to your `Capfile`:
  #
  #     require_relative "lib/capistrano_rsync" # adapt path as needed
  #     install_plugin Capistrano::SCM::Rsync
  #
  # Note that this you need to deactivate any other SCM plugins (there can only be one SCM plugin active at any time)-
  #
  # Deploying via rsync works in three steps:
  #
  #  1) A git checkout of the specified branched is performed into a local cache directory (`:rsync_local_cache`).
  #     Per default, this directory is persisted so that the next deploy only needs to do a “git pull” instead of
  #     a fresh clone. But you can delete this directory anytime, if you need/want do. (It will be recreated during
  #     the next deploy.)
  #
  #  2) The local cache directory is synced to the remote cache directory (`:rsync_remote_cache`) using rsync.
  #     Think of the remote cache directory as equivalent to the `repo` directory when deploying via git. It is there
  #     to avoid having to transfer all the files on each deploy. This, too, can be deleted (and will be recreated
  #     during the next deploy).
  #
  #     Per default, `:rsync_options` is set to exclude any git related files, thus none of these files will be
  #     transferred to the server.
  #
  #  3) The current state of the remote cache directory is copied to the release directory (also using rsync, but as
  #     the release directory is freshly created for each deploy, this is in fact just a full recursive copy).
  class Rsync < ::Capistrano::SCM::Plugin
    def set_defaults
      set_if_empty :rsync_options, %w[--archive --delete --exclude=.git*]

      # Local cache (Git checkout will be happen here, resulting files then get rsynced to the remote server)
      set_if_empty :rsync_local_cache, 'tmp/.capistrano-rsync-deploy'

      # Remote cache on the server. Will be synced with the local cache before each release, and then used as
      # source for the release. Saves needing to transfer all the source files for each release.
      set_if_empty :rsync_remote_cache, 'rsync-deploy'
    end

    def define_tasks
      namespace :rsync do
        desc 'Copy application source code from (remote) cache to release path.'
        task create_release: :update_remote_cache do
          on release_roles :all do
            execute :rsync, '--archive', "#{fetch(:deploy_to)}/#{fetch(:rsync_remote_cache)}/#{fetch(:rsync_deploy_build_path)}", "#{release_path}/"
          end
        end

        desc 'Update remote cache of application source code.'
        task update_remote_cache: :update_local_cache do
          on release_roles :all do |role|
            host_spec = role.hostname
            host_spec = "#{role.user}@#{host_spec}" if role.user
            run_locally do
              execute :rsync, *fetch(:rsync_options), "#{fetch(:rsync_local_cache)}/", "#{host_spec}:#{fetch(:deploy_to)}/#{fetch(:rsync_remote_cache)}/"
            end
          end
        end

        desc 'Update local cache of application source code.'
        task :update_local_cache do
          run_locally do
            unless File.exist?("#{fetch(:rsync_local_cache)}/.git")
              FileUtils.mkdir_p(fetch(:rsync_local_cache))
              execute :git, :clone, '--quiet', repo_url, fetch(:rsync_local_cache)
            end
            within fetch(:rsync_local_cache) do
              execute :git, :fetch, '--quiet', '--all', '--prune'
              execute :git, :checkout, fetch(:branch)
              execute :git, :reset, '--quiet', '--hard', "origin/#{fetch(:branch)}"
            end
          end
        end

        desc 'Determine the revision that will be deployed'
        task :set_current_revision do
          run_locally do
            within fetch(:rsync_local_cache) do
              set :current_revision, capture(:git, "rev-list --max-count=1 #{fetch(:branch)}")
            end
          end
        end
      end
    end

    def register_hooks
      after 'deploy:new_release_path', 'rsync:create_release'
      before 'deploy:set_current_revision', 'rsync:set_current_revision'
    end
  end
end
