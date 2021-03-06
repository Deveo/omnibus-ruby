#
# Copyright 2012-2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'singleton'

module Omnibus
  class Config
    include Cleanroom
    include NullArgumentable
    include Singleton
    include Util

    class << self
      #
      # @param [String] filepath
      #   the path to the config definition to load from disk
      #
      # @return [Config]
      #
      def load(filepath)
        evaluate_file(instance, filepath)
      end

      #
      # @macro default
      #   @method $1(value = NULL)
      #
      # @param [Symbol] key
      #   the name of the configuration value to create
      # @param [Object] default
      #   the default value
      # @param [Proc] block
      #   a block to be called for the default value. If the block is provided,
      #   the +default+ attribute is ignored
      #
      def default(key, default = NullArgumentable::NULL, &block)
        # This is a class method, which delegates to the instance method
        define_singleton_method(key) do |value = NullArgumentable::NULL|
          instance.send(key, value)
        end

        # This is an instance method, but this is a singleton object ;)
        define_method(key) do |value = NullArgumentable::NULL|
          set_or_return(key, value, default, &block)
        end

        # All config options should be avaiable as DSL methods
        expose(key)
      end

      #
      # Check if the configuration includes the given key.
      #
      # @param [Symbol] key
      #
      # @return [true, false]
      #
      def key?(key)
        public_method_defined?(key.to_sym)
      end
      alias_method :has_key?, :key?

      #
      # Get a value from the config object.
      #
      # @deprecated Use direct method instead
      #
      # @param [Symbol] key
      #   the key to fetch
      #
      # @return [Object]
      #
      def fetch(key)
        Omnibus.logger.deprecated('Config') do
          "fetch ([]). Please use `Config.#{key}' instead."
        end

        public_method_defined?(key.to_sym) && instance.send(key.to_sym)
      end
      alias_method :[], :fetch

      #
      # Reset the current configuration values. This method will unset any
      # "stored" or memorized configuration values.
      #
      # @return [true]
      #
      def reset!
        instance.instance_variables.each do |instance_variable|
          instance.send(:remove_instance_variable, instance_variable)
        end

        true
      end
    end

    #
    # @!group Directory Configuration Parameters
    # --------------------------------------------------

    # The "base" directory where Omnibus will store it's data. Other paths are
    # dynamically computed from this value.
    #
    # - Defaults to +C:\omnibus-ruby+ on Windows
    # - Defaults to +/var/cache/omnibus+ on other platforms
    #
    # @return [String]
    default(:base_dir) do
      if Ohai['platform'] == 'windows'
        'C:\\omnibus-ruby'
      else
        '/var/cache/omnibus'
      end
    end

    # The absolute path to the directory on the virtual machine where
    # code will be cached.
    #
    # @return [String]
    default(:cache_dir) { windows_safe_path(base_dir, 'cache') }

    # The absolute path to the directory on the virtual machine where
    # git caching will occur and software's will be progressively cached.
    #
    # @return [String]
    default(:git_cache_dir) do
      if defined?(@install_path_cache_dir)
        @install_path_cache_dir
      else
        windows_safe_path(base_dir, 'cache', 'git_cache')
      end
    end

    # @deprecated Use {#git_cache_dir} instead.
    #
    # @return [String]
    default(:install_path_cache_dir) do
      Omnibus.logger.deprecated('Config') do
        'Config.install_path_cache_dir. Plase use Config.git_cache_dir instead.'
      end

      git_cache_dir
    end

    # The absolute path to the directory on the virtual machine where
    # source code will be downloaded.
    #
    # @return [String]
    default(:source_dir) { windows_safe_path(base_dir, 'src') }

    # The absolute path to the directory on the virtual machine where
    # software will be built.
    #
    # @return [String]
    default(:build_dir) { windows_safe_path(base_dir, 'build') }

    # The absolute path to the directory on the virtual machine where
    # packages will be constructed.
    #
    # @return [String]
    default(:package_dir) { windows_safe_path(base_dir, 'pkg') }

    # The absolute path to the directory on the virtual machine where
    # packagers will store intermediate packaging products. Some packaging
    # methods (notably fpm) handle this internally so not all packagers will
    # use this setting.
    #
    # @return [String]
    default(:package_tmp) { windows_safe_path(base_dir, 'pkg-tmp') }

    # The relative path of the directory containing {Omnibus::Project}
    # DSL files.  This is relative to {#project_root}.
    #
    # @return [String]
    default(:project_dir, 'config/projects')

    # The relative path of the directory containing {Omnibus::Software}
    # DSL files.  This is relative {#project_root}.
    #
    # @return [String]
    default(:software_dir, 'config/software')

    # The root directory in which to look for {Omnibus::Project} and
    # {Omnibus::Software} DSL files.
    #
    # @return [String]
    default(:project_root) { Dir.pwd }

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group DMG / PKG configuration options
    # --------------------------------------------------

    # Package OSX pkg files inside a DMG
    #
    # @return [true, false]
    default(:build_dmg, true)

    # The starting x,y and ending x,y positions for the created DMG window.
    #
    # @return [String]
    default(:dmg_window_bounds, '100, 100, 750, 600')

    # The starting x,y position where the .pkg file should live in the DMG
    # window.
    #
    # @return [String]
    default(:dmg_pkg_position, '535, 50')

    # Sign the pkg package.
    #
    # @return [true, false]
    default(:sign_pkg, false)

    # The identity to sign the pkg with.
    #
    # @return [String]
    default(:signing_identity, nil)

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group S3 Caching Configuration Parameters
    # --------------------------------------------------

    # Indicate if you wish to cache software artifacts in S3 for
    # quicker build times.  Requires {#s3_bucket}, {#s3_access_key},
    # and {#s3_secret_key} to be set if this is set to +true+.
    #
    # @return [true, false]
    default(:use_s3_caching, false)

    # The name of the S3 bucket you want to cache software artifacts in.
    #
    # @return [String]
    default(:s3_bucket) do
      raise MissingConfigOption.new(:s3_bucket, "'my_bucket'")
    end

    # The S3 access key to use with S3 caching.
    #
    # @return [String]
    default(:s3_access_key) do
      raise MissingConfigOption.new(:s3_access_key, "'ABCD1234'")
    end

    # The S3 secret key to use with S3 caching.
    #
    # @return [String]
    default(:s3_secret_key) do
      raise MissingConfigOption.new(:s3_secret_key, "'EFGH5678'")
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Artifactory Publisher
    # --------------------------------------------------

    # The full URL where the artifactory instance is accessible.
    #
    # @return [String]
    default(:artifactory_endpoint) do
      raise MissingConfigOption.new(:artifactory_endpoint, "'https://...'")
    end

    # The username of the artifactory user to authenticate with.
    #
    # @return [String]
    default(:artifactory_username) do
      raise MissingConfigOption.new(:artifactory_username, "'admin'")
    end

    # The password of the artifactory user to authenticate with.
    #
    # @return [String]
    default(:artifactory_password) do
      raise MissingConfigOption.new(:artifactory_password, "'password'")
    end

    # The path on disk to an SSL pem file to sign requests with.
    #
    # @return [String, nil]
    default(:artifactory_ssl_pem_file, nil)

    # Whether to perform SSL verification when connecting to artifactory.
    #
    # @return [true, false]
    default(:artifactory_ssl_verify, true)

    # The username to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_username, nil)

    # The password to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_password, nil)

    # The address to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_address, nil)

    # The port to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_port, nil)

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group S3 Publisher
    # --------------------------------------------------

    # The S3 access key to use for S3 artifact release.
    #
    # @return [String]
    default(:publish_s3_access_key) do
      raise MissingConfigOption.new(:publish_s3_access_key, "'ABCD1234'")
    end

    # The S3 secret key to use for S3 artifact release
    #
    # @return [String]
    default(:publish_s3_secret_key) do
      raise MissingConfigOption.new(:publish_s3_secret_key, "'EFGH5678'")
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Miscellaneous Configuration Parameters
    # --------------------------------------------------

    # The path to an overrides file.
    #
    # @return [true, false]
    default(:override_file, nil)

    # The gem to pull software definitions from.  This is just the name of the
    # gem, which is used to find the path to your software definitions, and you
    # must also specify this gem in the Gemfile of your project repo in order to
    # include the gem in your bundle.
    #
    # @return [String]
    default(:software_gem, 'omnibus-software')

    # The solaris compiler to use
    #
    # @return [String, nil]
    default(:solaris_compiler, nil)

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Build Parameters
    # --------------------------------------------------

    # Append the current timestamp to the version identifier.
    #
    # @return [true, false]
    default(:append_timestamp, true)

    # The number of times to retry the build before failing.
    #
    # @return [Integer]
    default(:build_retries, 3)

    # Use the incremental build caching implemented via git. This will
    # drastically improve build times, but may result in hidden and
    # unexpected bugs.
    #
    # @return [true, false]
    default(:use_git_caching, true)

    # --------------------------------------------------
    # @!endgroup
    #

    private

    #
    #
    #
    def set_or_return(key, value = NULL, default = NULL, &block)
      instance_variable = :"@#{key}"

      if null?(value)
        if instance_variable_defined?(instance_variable)
          instance_variable_get(instance_variable)
        else
          if block
            instance_eval(&block)
          else
            null?(default) ? nil : default
          end
        end
      else
        instance_variable_set(instance_variable, value)
      end
    end
  end
end
