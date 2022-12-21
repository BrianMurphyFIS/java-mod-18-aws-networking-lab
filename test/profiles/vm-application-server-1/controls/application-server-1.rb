title "Application VM checks"


control 'Application VM SSHD check' do
  impact 'critical'
  title 'Application VM SSHD check'
  desc 'Application VM SSHD should be running'
  desc 'step', '8'

  describe service('sshd') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end


control 'Application VM Docker check' do
  impact 'critical'
  title 'Application VM Docker check'
  desc 'Application VM Docker should be running'
  desc 'step', '8'

  describe service('docker') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end


control 'Application VM Docker Permission check' do
  impact 'critical'
  title 'Application VM Docker Permission check'
  desc 'Application VM Docker should have correct access'
  desc 'step', '8'

  describe groups.where { name == 'docker' } do
    it { should exist }
    its('members') { should include 'ubuntu' }
  end
end


control 'Application VM Redis-Commander Container' do
  impact 'critical'
  title 'Application VM Redis-Commander Container'
  desc 'Application VM Redis-Commander Container should be running'
  desc 'step', '8'

  describe docker.images.where { repository == 'rediscommander/redis-commander' } do
    it { should exist }
  end
  describe docker.containers.where { names == 'redis-commander' && image == 'rediscommander/redis-commander:latest' && ports =~ /0.0.0.0:80->8081/ } do
    its('status') { should match [/Up/] }
  end
  describe http('http://127.0.0.1:80/') do
    its('status') { should eq 200 }
  end
end
