require 'rspec/core/rake_task'

task :default do
  ruby = RbConfig::CONFIG['ruby_install_name']
  # mysql test doesn't work anymore under fakeroot
  # disable it for now
  # see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=963319
  #sh "./debian/start_services_and_run.sh #{ruby} -S rspec"
end
