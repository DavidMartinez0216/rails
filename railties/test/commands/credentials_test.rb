# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/credentials/credentials_command"
require "fileutils"

class Rails::Command::CredentialsCommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  test "edit without editor gives hint" do
    run_edit_command(editor: "").tap do |output|
      assert_match "No $EDITOR to open file in", output
      assert_match "rails credentials:edit", output
    end
  end

  test "edit credentials" do
    # Run twice to ensure credentials can be reread after first edit pass.
    2.times do
      assert_match(/access_key_id: 123/, run_edit_command)
    end
  end

  test "edit command does not add master key to gitignore when already exist" do
    run_edit_command

    Dir.chdir(app_path) do
      gitignore = File.read(".gitignore")
      assert_equal 1, gitignore.scan(%r|config/master\.key|).length
    end
  end

  test "edit command does not overwrite by default if credentials already exists" do
    run_edit_command(editor: "eval echo api_key: abc >")
    assert_match(/api_key: abc/, run_show_command)

    run_edit_command
    assert_match(/api_key: abc/, run_show_command)
  end

  test "edit command does not add master key when `RAILS_MASTER_KEY` env specified" do
    Dir.chdir(app_path) do
      key = IO.binread("config/master.key").strip
      FileUtils.rm("config/master.key")

      switch_env("RAILS_MASTER_KEY", key) do
        assert_match(/access_key_id: 123/, run_edit_command)
        assert_not File.exist?("config/master.key")
      end
    end
  end

  test "edit command modifies file specified by environment option" do
    assert_match(/access_key_id: 123/, run_edit_command(environment: "production"))
    Dir.chdir(app_path) do
      assert File.exist?("config/credentials/production.key")
      assert File.exist?("config/credentials/production.yml.enc")
    end
  end

  test "edit command properly expands environment option" do
    assert_match(/access_key_id: 123/, run_edit_command(environment: "prod"))
    Dir.chdir(app_path) do
      assert File.exist?("config/credentials/production.key")
      assert File.exist?("config/credentials/production.yml.enc")
    end
  end

  test "edit command does not raise when an initializer tries to access non-existent credentials" do
    app_file "config/initializers/raise_when_loaded.rb", <<-RUBY
      Rails.application.credentials.missing_key!
    RUBY

    assert_match(/access_key_id: 123/, run_edit_command(environment: "qa"))
  end

  test "edit command generates template file when the file does not exist" do
    FileUtils.rm("#{app_path}/config/credentials.yml.enc")
    run_edit_command

    output = run_show_command
    assert_match(/access_key_id: 123/, output)
    assert_match(/secret_key_base/, output)
  end


  test "show credentials" do
    assert_match(/access_key_id: 123/, run_show_command)
  end

  test "show command raises error when require_master_key is specified and key does not exist" do
    remove_file "config/master.key"
    add_to_config "config.require_master_key = true"

    assert_match(/Missing encryption key to decrypt file with/, run_show_command(allow_failure: true))
  end

  test "show command does not raise error when require_master_key is false and master key does not exist" do
    remove_file "config/master.key"
    add_to_config "config.require_master_key = false"

    assert_match(/Missing 'config\/master\.key' to decrypt credentials/, run_show_command)
  end

  test "show command displays content specified by environment option" do
    run_edit_command(environment: "production")

    assert_match(/access_key_id: 123/, run_show_command(environment: "production"))
  end

  test "show command properly expands environment option" do
    run_edit_command(environment: "production")

    output = run_show_command(environment: "prod")
    assert_match(/access_key_id: 123/, output)
    assert_no_match(/secret_key_base/, output)
  end


  test "diff enroll diffing" do
    assert_match(/\benrolled project/i, run_diff_command(enroll: true))

    assert_includes File.read(app_path(".gitattributes")), <<~EOM
      config/credentials/*.yml.enc diff=rails_credentials
      config/credentials.yml.enc diff=rails_credentials
    EOM
  end

  test "diff enroll diffing when already enrolled" do
    run_diff_command(enroll: true)

    assert_match(/already enrolled/i, run_diff_command(enroll: true))

    assert_equal 1, File.read(app_path(".gitattributes")).scan("config/credentials.yml.enc").length
  end

  test "diff disenroll diffing" do
    FileUtils.rm(app_path(".gitattributes"))
    run_diff_command(enroll: true)

    assert_match(/\bdisenrolled project/i, run_diff_command(disenroll: true))

    assert_not File.exist?(app_path(".gitattributes"))
  end

  test "diff disenroll diffing with existing .gitattributes" do
    File.write(app_path(".gitattributes"), "foo bar\n")
    run_diff_command(enroll: true)

    run_diff_command(disenroll: true)

    assert_equal("foo bar\n", File.read(app_path(".gitattributes")))
  end

  test "diff disenroll diffing when not enrolled" do
    FileUtils.rm(app_path(".gitattributes"))

    assert_match(/not enrolled/i, run_diff_command(disenroll: true))

    assert_not File.exist?(app_path(".gitattributes"))
  end

  test "running edit after enrolling in diffing sets diff driver" do
    run_diff_command(enroll: true)
    run_edit_command

    Dir.chdir(app_path) do
      assert_equal "bin/rails credentials:diff", `git config --get 'diff.rails_credentials.textconv'`.strip
    end
  end

  test "diff from git diff left file" do
    run_edit_command(environment: "development")

    assert_match(/access_key_id: 123/, run_diff_command("config/credentials/development.yml.enc"))
  end

  test "diff from git diff right file" do
    run_edit_command(environment: "development")

    content_path = app_path("config", "credentials", "KnAM4a_development.yml.enc")
    File.write(content_path,
      File.read(app_path("config", "credentials", "development.yml.enc")))

    assert_match(/access_key_id: 123/, run_diff_command(content_path))
  end

  test "diff for main credentials" do
    assert_match(/access_key_id: 123/, run_diff_command("config/credentials.yml.enc"))
  end

  test "diff when master key is not available" do
    remove_file "config/master.key"

    raw_content = File.read(app_path("config", "credentials.yml.enc"))
    assert_match(raw_content, run_diff_command("config/credentials.yml.enc"))
  end

  test "diff returns raw encrypted content when errors occur" do
    run_edit_command(environment: "development")

    content_path = app_path("20190807development.yml.enc")
    encrypted_content = File.read(app_path("config", "credentials", "development.yml.enc"))
    File.write(content_path, encrypted_content + "ruin decryption")

    assert_match(encrypted_content, run_diff_command(content_path))
  end

  test "edit/show commands with environment option use custom paths when they are set" do
    add_to_env_config("development", "config.credentials.key_path = 'config/credentials/custom.key'")
    add_to_env_config("development", "config.credentials.content_path = 'config/credentials/custom.yml.enc'")

    run_edit_command(environment: "development")

    Dir.chdir(app_path) do
      assert File.exist?("config/credentials/custom.key"), "Expected custom credentials key file to exist"
      assert File.exist?("config/credentials/custom.yml.enc"), "Expected custom credentials content file to exist"
    end
    assert_match(/access_key_id: 123/, run_show_command(environment: "development"))
  end

  test "edit/show commands with no environment option still use default paths when dev and custom credentials exist" do
    remove_file "config/master.key"
    remove_file "config/credentials.yml.enc"
    write_credentials_override("development")
    write_credentials_override("custom")
    add_to_env_config("development", "config.credentials.key_path = 'config/credentials/custom.key'")
    add_to_env_config("development", "config.credentials.content_path = 'config/credentials/custom.yml.enc'")

    run_edit_command

    Dir.chdir(app_path) do
      assert File.exist?("config/master.key"), "Expected master.key to exist"
      assert File.exist?("config/credentials.yml.enc"), "Expected credentials.yml.enc to exist"
    end
    assert_match(/access_key_id: 123/, run_show_command)
  end

  test "edit/show commands with environment option use correct environment paths when development credentials exist" do
    write_credentials_override("development")

    run_edit_command(environment: "production")

    Dir.chdir(app_path) do
      assert File.exist?("config/credentials/production.key"), "Expected production key file to exist"
      assert File.exist?("config/credentials/production.yml.enc"), "Expected production content file to exist"
    end
    assert_match(/access_key_id: 123/, run_show_command(environment: "production"))
  end

  test "edit/show commands with non-dev environment option use custom environment config" do
    write_credentials_override("development")
    add_to_env_config("production", "config.credentials.key_path = 'config/credentials/custom.key'")
    add_to_env_config("production", "config.credentials.content_path = 'config/credentials/custom.yml.enc'")

    run_edit_command(environment: "production")

    Dir.chdir(app_path) do
      assert File.exist?("config/credentials/custom.key"), "Expected custom credentials key file to exist"
      assert File.exist?("config/credentials/custom.yml.enc"), "Expected custom credentials content file to exist"
    end
    assert_match(/access_key_id: 123/, run_show_command(environment: "production"))
  end

  test "edit/show commands use application config paths" do
    add_to_config("config.credentials.key_path = 'config/credentials/custom.key'")
    add_to_config("config.credentials.content_path = 'config/credentials/custom.yml.enc'")

    run_edit_command
    run_edit_command(environment: "production")

    Dir.chdir(app_path) do
      assert File.exist?("config/credentials/custom.key"), "Expected custom credentials key file to exist"
      assert File.exist?("config/credentials/custom.yml.enc"), "Expected custom credentials content file to exist"
      assert_not File.exist?("config/credentials/development.yml.enc"), "Expected development credentials not to exist"
      assert_not File.exist?("config/credentials/production.yml.enc"), "Expected production credentials not to exist"
    end
    assert_match(/access_key_id: 123/, run_show_command)
    assert_match(/access_key_id: 123/, run_show_command(environment: "production"))
  end

  test "edit/show commands use application config paths when dev credentials exist" do
    write_credentials_override("development")
    add_to_config("config.credentials.key_path = 'config/credentials/custom.key'")
    add_to_config("config.credentials.content_path = 'config/credentials/custom.yml.enc'")

    run_edit_command
    run_edit_command(environment: "production")

    Dir.chdir(app_path) do
      assert File.exist?("config/credentials/custom.key"), "Expected custom credentials key file to exist"
      assert File.exist?("config/credentials/custom.yml.enc"), "Expected custom credentials content file to exist"
      assert_not File.exist?("config/credentials/production.yml.enc"), "Expected production credentials not to exist"
    end
    assert_match(/access_key_id: 123/, run_show_command)
    assert_match(/access_key_id: 123/, run_show_command(environment: "production"))
  end

  private
    def run_edit_command(editor: "cat", environment: nil, **options)
      switch_env("EDITOR", editor) do
        args = environment ? ["--environment", environment] : []
        rails "credentials:edit", args, **options
      end
    end

    def run_show_command(environment: nil, **options)
      args = environment ? ["--environment", environment] : []
      rails "credentials:show", args, **options
    end

    def run_diff_command(path = nil, enroll: nil, disenroll: nil, **options)
      args = [path, ("--enroll" if enroll), ("--disenroll" if disenroll)].compact
      rails "credentials:diff", args, **options
    end

    def write_credentials_override(name, with_key: true)
      Dir.chdir(app_path) do
        Dir.mkdir  "config/credentials" unless File.exist?("config/credentials")
        File.write "config/credentials/#{name}.key", credentials_key if with_key

        # secret_key_base: secret
        # mystery: revealed
        File.write "config/credentials/#{name}.yml.enc",
          "vgvKu4MBepIgZ5VHQMMPwnQNsLlWD9LKmJHu3UA/8yj6x+3fNhz3DwL9brX7UA==--qLdxHP6e34xeTAiI--nrcAsleXuo9NqiEuhntAhw=="
      end
    end

    def credentials_key
      "2117e775dc2024d4f49ddf3aeb585919"
    end
end
