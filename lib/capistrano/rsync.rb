require 'capistrano/scm/plugin'

class Capistrano::SCM
  class Rsync < ::Capistrano::SCM::Plugin
    def set_defaults
       # command-line options for rsync
      set_if_empty :rsync_options, %w[--archive --delete --exclude=.git*]

      # Local cache (Git checkout will be happen here, resulting files then get rsynced to the remote server)
      set_if_empty :rsync_local_cache, 'tmp/.capistrano-rsync-deploy'

      # Remote cache on the server. Will be synced with the local cache before each release, and then used as
      # source for the release. Saves needing to transfer all the source files for each release.
      set_if_empty :rsync_remote_cache, 'rsync-deploy'

      # Git fetch automaticly submodules
      set_if_empty :rsync_git_submodules, true
    end

    def define_tasks
      namespace :rsync do
        desc <<-DESC
            Copy application source code from (remote) cache to release path.

            If a :rsync_deploy_build_path is set, only that relative path will \
            be copied to the release path.
        DESC
        task create_release: :update_remote_cache do
          on release_roles :all do
            execute :rsync, '--archive', "#{fetch(:deploy_to)}/#{fetch(:rsync_remote_cache)}/#{fetch(:rsync_deploy_build_path)}", "#{release_path}/"
          end
        end

        desc <<-DESC
            Update remote cache of application source code.

            This will be rsynced to :rsync_remote_cache, using rsync options set in \
            :rsync_options
        DESC
        task update_remote_cache: :update_local_cache do
          on release_roles :all do |role|
            host_spec = role.hostname
            host_spec = "#{role.user}@#{host_spec}" if role.user
            run_locally do
              execute :rsync, *fetch(:rsync_options), "#{fetch(:rsync_local_cache)}/", "#{host_spec}:#{fetch(:deploy_to)}/#{fetch(:rsync_remote_cache)}/"
            end
          end
        end

        desc <<-DESC
            Update local cache of application source code.

            This will be checked out to :rsync_local_cache.
        DESC
        task :update_local_cache do
          run_locally do
            unless File.exist?("#{fetch(:rsync_local_cache)}/.git")
              FileUtils.mkdir_p(fetch(:rsync_local_cache))
              recursive_submodules = fetch(:rsync_git_submodules) ? '--recurse-submodules' : ''
              execute :git, :clone, recursive_submodules, '--quiet', repo_url, fetch(:rsync_local_cache)
            end
            within fetch(:rsync_local_cache) do
              execute :git, :fetch, '--quiet', '--all', '--prune'
              execute :git, :checkout, fetch(:branch)
              execute :git, :reset, '--quiet', '--hard', "origin/#{fetch(:branch)}"
              execute :git, :submodule, :update, '--recursive', '--init' if fetch(:rsync_git_submodules)
            end
          end
        end

        desc <<-DESC
            Determine version of code that rsync will deploy.

            By default, this is the latest version of the code on branch :branch.
        DESC
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
