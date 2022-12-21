title "Database VM checks"


control 'Database VM SSHD check' do
  impact 'critical'
  title 'Database VM SSHD check'
  desc 'Database VM SSHD should be running'
  desc 'step', '7'

  describe service('sshd') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end


control 'Database VM Docker check' do
  impact 'critical'
  title 'Database VM Docker check'
  desc 'Database VM Docker should be running'
  desc 'step', '7'

  describe service('docker') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end


control 'Database VM Docker Permission check' do
  impact 'critical'
  title 'Database VM Docker Permission check'
  desc 'Database VM Docker should have correct access'
  desc 'step', '7'

  describe groups.where { name == 'docker' } do
    it { should exist }
    its('members') { should include 'ubuntu' }
  end
end


control 'Database VM Redis Container' do
  impact 'critical'
  title 'Database VM Redis Container'
  desc 'Database VM Redis Container should be running'
  desc 'step', '13'

  describe docker.images.where { repository == 'redis' } do
    it { should exist }
  end
  describe docker.containers.where { names == 'redis' && image == 'redis' && ports =~ /0.0.0.0:6379->6379/ } do
    its('status') { should match [/Up/] }
  end
  describe bash("echo -e 'PING' | nc -w1 127.0.0.1 6379") do
    its('stdout') { should match /PONG/ }
  end
end
