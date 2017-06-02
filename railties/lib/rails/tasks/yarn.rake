namespace :yarn do
  desc "Install all JavaScript dependencies as specified via Yarn"
  task :install do
    system("./bin/yarn install --no-progress")
  end
end
