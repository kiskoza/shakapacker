require_relative "spec_helper_initializer"
# Requiring from webpacker directory to ensure old ./bin/webpacker-dev-server works fine
require "webpacker/dev_server_runner"

describe "DevServerRunner" do
  before do
    @original_node_env, ENV["NODE_ENV"] = ENV["NODE_ENV"], "development"
    @original_rails_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "development"
    @original_webpacker_config = ENV["WEBPACKER_CONFIG"]
  end

  after do
    ENV["NODE_ENV"] = @original_node_env
    ENV["RAILS_ENV"] = @original_rails_env
    ENV["WEBPACKER_CONFIG"] = @original_webpacker_config
  end

  let(:test_app_path) { File.expand_path("webpacker_test_app", __dir__) }

  NODE_PACKAGE_MANAGERS.each do |fallback_manager|
    context "when using package_json with #{fallback_manager} as the manager" do
      with_use_package_json_gem(enabled: true, fallback_manager: fallback_manager)

      let(:package_json) { PackageJson.read(test_app_path) }

      require "package_json"

      it "uses the expected package manager", unless: fallback_manager == "yarn_classic" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        manager_name = fallback_manager.split("_")[0]

        expect(cmd).to start_with(manager_name)
      end

      it "runs the command using the manager" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        verify_command(cmd)
      end

      it "passes on arguments" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--quiet"])

        verify_command(cmd, argv: (["--quiet"]))
      end

      it "does not automatically pass the --https flag" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])

        allow(Shakapacker::DevServer).to receive(:new).and_return(
          double(
            host: "localhost",
            port: "3035",
            pretty?: false,
            protocol: "https",
            hmr?: false
          )
        )

        verify_command(cmd)
      end

      it "supports the https flag" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--https"])

        allow(Shakapacker::DevServer).to receive(:new).and_return(
          double(
            host: "localhost",
            port: "3035",
            pretty?: false,
            protocol: "https",
            hmr?: false
          )
        )

        verify_command(cmd, argv: ["--https"])
      end

      it "supports hot module reloading" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--hot"])

        allow(Shakapacker::DevServer).to receive(:new).and_return(
          double(
            host: "localhost",
            port: "3035",
            pretty?: false,
            protocol: "http",
            hmr?: true
          )
        )

        verify_command(cmd)
      end

      it "accepts environment variables" do
        cmd = package_json.manager.native_exec_command("webpack", ["serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"])
        env = Webpacker::Compiler.env.dup

        # ENV["WEBPACKER_CONFIG"] is the interface and env["SHAKAPACKER_CONFIG"] is internal
        ENV["WEBPACKER_CONFIG"] = env["SHAKAPACKER_CONFIG"] = "#{test_app_path}/config/webpacker_other_location.yml"
        env["WEBPACK_SERVE"] = "true"

        verify_command(cmd, env: env)
      end
    end
  end

  context "when not using package_json" do
    with_use_package_json_gem(enabled: false)

    it "supports running via node modules" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]

      verify_command(cmd, use_node_modules: true)
    end

    it "supports running via yarn" do
      cmd = ["yarn", "webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]

      verify_command(cmd, use_node_modules: false)
    end

    it "passes on arguments" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--quiet"]

      verify_command(cmd, argv: (["--quiet"]))
    end

    it "does not automatically pass the --https flag" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]

      allow(Shakapacker::DevServer).to receive(:new).and_return(
        double(
          host: "localhost",
          port: "3035",
          pretty?: false,
          protocol: "https",
          hmr?: false
        )
      )

      verify_command(cmd)
    end

    it "supports the https flag" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--https"]

      allow(Shakapacker::DevServer).to receive(:new).and_return(
        double(
          host: "localhost",
          port: "3035",
          pretty?: false,
          protocol: "https",
          hmr?: false
        )
      )

      verify_command(cmd, argv: ["--https"])
    end

    it "supports hot module reloading" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js", "--hot"]

      allow(Shakapacker::DevServer).to receive(:new).and_return(
        double(
          host: "localhost",
          port: "3035",
          pretty?: false,
          protocol: "http",
          hmr?: true
        )
      )

      verify_command(cmd)
    end

    it "accepts environment variables" do
      cmd = ["#{test_app_path}/node_modules/.bin/webpack", "serve", "--config", "#{test_app_path}/config/webpack/webpack.config.js"]
      env = Webpacker::Compiler.env.dup

      # ENV["WEBPACKER_CONFIG"] is the interface and env["SHAKAPACKER_CONFIG"] is internal
      ENV["WEBPACKER_CONFIG"] = env["SHAKAPACKER_CONFIG"] = "#{test_app_path}/config/webpacker_other_location.yml"
      env["WEBPACK_SERVE"] = "true"

      verify_command(cmd, env: env)
    end
  end

  private

    def verify_command(cmd, use_node_modules: true, argv: [], env: Webpacker::Compiler.env)
      Dir.chdir(test_app_path) do
        klass = Webpacker::DevServerRunner
        instance = klass.new(argv)

        allow(klass).to receive(:new).and_return(instance)
        allow(instance).to receive(:node_modules_bin_exist?).and_return(use_node_modules)
        allow(Kernel).to receive(:exec).with(env, *cmd)

        klass.run(argv)

        expect(Kernel).to have_received(:exec).with(env, *cmd)
      end
    end
end
